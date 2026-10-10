-- Synthetic site-day observations for the remittance inclusion programme of a
-- fictional Philippine rural bank. A site is one fictional remittance pickup
-- partner (pawnshop branch, rural bank branch, cooperative office, money
-- transfer kiosk or mall service desk) in one of five Philippine cities, where
-- remittance recipients are offered a basic savings account.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-site dropout propensity, follow-up backlog between
-- dormant-account follow-up rounds, missed follow-ups, format-weighted onboarding
-- blockers, blockers resolved without an abandoned application, and two
-- city-wide power interruptions.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.SITES AS
WITH sites AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS SITE_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT SITE_INDEX,
         MOD(ABS(HASH(SITE_INDEX, 'phri-tenure')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(SITE_INDEX, 'phri-propensity')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(SITE_INDEX, 'phri-followup')), 1000000) / 1e6 AS U_FOLLOWUP,
         MOD(ABS(HASH(SITE_INDEX, 'phri-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(SITE_INDEX, 'phri-tier')), 1000000) / 1e6 AS U_TIER
  FROM sites
)
SELECT 'RS-' || LPAD(SITE_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic site ' || LPAD(SITE_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (5 and 8 are coprime): every city and format is present.
       CASE MOD(SITE_INDEX, 5) WHEN 0 THEN 'Batangas City' WHEN 1 THEN 'Tacloban City'
            WHEN 2 THEN 'General Santos City' WHEN 3 THEN 'Angeles City' ELSE 'Naga City' END AS REGION,
       CASE MOD(SITE_INDEX, 8) WHEN 0 THEN 'Pawnshop branch' WHEN 1 THEN 'Pawnshop branch'
            WHEN 2 THEN 'Pawnshop branch' WHEN 3 THEN 'Rural bank branch' WHEN 4 THEN 'Rural bank branch'
            WHEN 5 THEN 'Cooperative office' WHEN 6 THEN 'Money transfer kiosk' ELSE 'Mall service desk' END AS CATEGORY,
       SITE_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.5 + U_AGE * 11.5, 1) AS SITE_TENURE_YEARS,
       -- Base daily probability of an abandoned-application day 0.7%-3.3%;
       -- ~12% of sites are chronically weak (x3).
       (0.007 + U_RATE * 0.026) * IFF(U_RATE > 0.88, 3, 1) AS BASE_DROPOUT_RATE,
       5 * (1 + FLOOR(U_FOLLOWUP * 3)) AS FOLLOWUP_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.42 AS FOLLOWUP_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.SITE_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), city_events AS (
  -- Two city-wide power interruptions; every site in the city logs a blocker
  -- that is resolved once power is restored.
  SELECT * FROM VALUES (34, 'Tacloban City'), (71, 'Naga City') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT r.ID AS ENTITY_ID, r.SITE_INDEX, r.CATEGORY, r.REGION, r.SITE_TENURE_YEARS,
         r.BASE_DROPOUT_RATE, r.FOLLOWUP_INTERVAL_DAYS, r.FOLLOWUP_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + r.SITE_INDEX * 2, r.FOLLOWUP_INTERVAL_DAYS) AS DAYS_SINCE_FOLLOWUP,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phri-drop')), 1000000) / 1e6 AS U_FAIL,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phri-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phri-clear')), 1000000) / 1e6 AS U_CLEAR,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phri-type')), 1000000) / 1e6 AS U_TYPE,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phri-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phri-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phri-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phri-sla')), 1000000) / 1e6 AS U_SLA,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phri-open')), 1000000) / 1e6 AS U_OPEN,
         e.REGION IS NOT NULL AS CITY_EVENT
  FROM RAW.SITES r CROSS JOIN days d
  LEFT JOIN city_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = r.REGION
), followup AS (
  SELECT *,
         IFF(DAYS_SINCE_FOLLOWUP = 0, 1, 0) AS FOLLOWUP_DUE,
         IFF(DAYS_SINCE_FOLLOWUP = 0 AND U_DONE < FOLLOWUP_COMPLETION_PROB, 1, 0) AS FOLLOWUP_COMPLETED,
         -- Backlog rises between follow-up rounds; weak discipline carries it over.
         DAYS_SINCE_FOLLOWUP / FOLLOWUP_INTERVAL_DAYS + (1 - FOLLOWUP_COMPLETION_PROB) AS DRIFT
  FROM base
), dropouts AS (
  SELECT *,
         CASE WHEN U_FAIL < LEAST(0.5, BASE_DROPOUT_RATE * (0.5 + 1.4 * DRIFT) * (1 + 1 / (1 + SITE_TENURE_YEARS / 3))) / 4 THEN 2
              WHEN U_FAIL < LEAST(0.5, BASE_DROPOUT_RATE * (0.5 + 1.4 * DRIFT) * (1 + 1 / (1 + SITE_TENURE_YEARS / 3))) THEN 1
              ELSE 0 END AS DROPOUT_RISK_COUNT
  FROM followup
), blockers AS (
  SELECT *,
         -- About 82% of at-risk days log a blocker that ends in abandoned
         -- applications; the rest recover without one being logged.
         IFF(CITY_EVENT, 0, IFF(U_DETECT < 0.82, DROPOUT_RISK_COUNT, 0)) AS DROPOUT_COUNT,
         -- Blockers resolved on the spot: higher for busy formats.
         IFF(CITY_EVENT, 1, IFF(U_CLEAR < CASE CATEGORY WHEN 'Money transfer kiosk' THEN 0.17
                                                        WHEN 'Mall service desk' THEN 0.15
                                                        WHEN 'Rural bank branch' THEN 0.11 ELSE 0.07 END, 1, 0)) AS CLEARED_COUNT
  FROM dropouts
), measured AS (
  SELECT *,
         DROPOUT_COUNT + CLEARED_COUNT AS BLOCKER_COUNT,
         ROUND(CASE CATEGORY WHEN 'Pawnshop branch' THEN 310 WHEN 'Money transfer kiosk' THEN 260
                             WHEN 'Mall service desk' THEN 230 WHEN 'Rural bank branch' THEN 140 ELSE 95 END
               * (0.7 + 0.6 * U_VOLUME) * (1 + 0.6 * DROPOUT_RISK_COUNT)) AS PICKUP_COUNT,
         CASE CATEGORY WHEN 'Pawnshop branch' THEN 7400 WHEN 'Money transfer kiosk' THEN 5900
                       WHEN 'Mall service desk' THEN 8800 WHEN 'Rural bank branch' THEN 10200 ELSE 6300 END
           * (0.8 + 0.4 * U_NOISE) AS AVG_PAYOUT_PHP,
         -- Share of pickups that open a basic savings account: 1.5%-4.5%, lower on dropout days.
         (0.015 + 0.03 * U_OPEN) * (1 - 0.35 * DROPOUT_RISK_COUNT / 2) AS OPEN_RATE
  FROM blockers
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       PICKUP_COUNT,
       ROUND(PICKUP_COUNT * AVG_PAYOUT_PHP, 2) AS PAYOUT_PHP,
       ROUND(PICKUP_COUNT * OPEN_RATE) AS ACCOUNTS_OPENED,
       BLOCKER_COUNT, DROPOUT_COUNT,
       IFF(DROPOUT_COUNT > 0 AND U_SLA < 0.5, 1, 0) AS SLA_BREACHED,
       CASE WHEN BLOCKER_COUNT = 0 THEN 'None'
            WHEN CITY_EVENT THEN 'Area power interruption'
            WHEN CATEGORY = 'Pawnshop branch' THEN IFF(U_TYPE < 0.45, 'Missing valid ID', IFF(U_TYPE < 0.8, 'Proof of address gap', 'Beneficiary name mismatch'))
            WHEN CATEGORY = 'Rural bank branch' THEN IFF(U_TYPE < 0.4, 'Core banking timeout', IFF(U_TYPE < 0.75, 'Missing valid ID', 'Proof of address gap'))
            WHEN CATEGORY = 'Cooperative office' THEN IFF(U_TYPE < 0.5, 'Proof of address gap', IFF(U_TYPE < 0.8, 'Membership form incomplete', 'Network link down'))
            WHEN CATEGORY = 'Money transfer kiosk' THEN IFF(U_TYPE < 0.5, 'eKYC selfie mismatch', IFF(U_TYPE < 0.8, 'Network link down', 'Beneficiary name mismatch'))
            ELSE IFF(U_TYPE < 0.45, 'eKYC selfie mismatch', 'Core banking timeout') END AS BLOCKER_TYPE,
       FOLLOWUP_DUE, FOLLOWUP_COMPLETED,
       ROUND(0.6 + 1.7 * DRIFT + 2.9 * DROPOUT_RISK_COUNT + U_NOISE * 0.9, 2) AS EKYC_ERROR_PCT,
       ROUND(11 + 6 * DRIFT + 14 * DROPOUT_RISK_COUNT + U_NOISE * 4, 1) AS AVG_ONBOARD_MIN,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Partner accreditation document coverage per site (snapshot).
CREATE TABLE RAW.PARTNER_DOCUMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Pawnshop branch' THEN 'Partner agency agreement'
                     WHEN 'Rural bank branch' THEN 'Staff KYC training record'
                     WHEN 'Cooperative office' THEN 'Cooperative board resolution'
                     WHEN 'Money transfer kiosk' THEN 'Kiosk site permit'
                     ELSE 'Mall lease and permit' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'phri-req')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'phri-file')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'phri-file')), 5) < 1 + MOD(ABS(HASH(ID, 'phri-req')), 4),
           MOD(ABS(HASH(ID, 'phri-pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.SITES;
