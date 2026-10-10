-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-blocker alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_PICKUPS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic onboarding-blocker knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.BLOCKER_DOCS AS
WITH types AS (
  SELECT DISTINCT r.BLOCKER_TYPE, a.CATEGORY
  FROM RAW.SITE_DAILY r JOIN RAW.SITES a ON a.ID = r.ENTITY_ID
  WHERE r.DROPOUT_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, BLOCKER_TYPE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  BLOCKER_TYPE,
  CATEGORY || ' - ' || BLOCKER_TYPE || ' onboarding blocker handling' AS TITLE,
  'Synthetic demo SOP. Site format: ' || CATEGORY || '. Blocker type: ' || BLOCKER_TYPE || '. '
  || 'Step 1: log the blocker in the inclusion desk console, keep the remittance payout separate from the account application, and tell the recipient what is needed to finish opening the account. '
  || 'Step 2: ' || CASE
       WHEN BLOCKER_TYPE = 'Missing valid ID' THEN 'list the accepted identity documents from the programme checklist, offer a scheduled return visit, and save the partly completed application so the recipient does not start again.'
       WHEN BLOCKER_TYPE = 'Proof of address gap' THEN 'check whether the programme checklist allows an alternative proof of address, record which one was used, and route unclear cases to the compliance review queue.'
       WHEN BLOCKER_TYPE = 'Beneficiary name mismatch' THEN 'compare the name on the remittance with the identity document, record the difference, and route the application to the compliance review queue instead of correcting it at the desk.'
       WHEN BLOCKER_TYPE = 'eKYC selfie mismatch' THEN 'retake the selfie in better light once, then switch to assisted verification by a desk officer if the second attempt also fails.'
       WHEN BLOCKER_TYPE = 'Core banking timeout' THEN 'keep the application reference number, do not resubmit until the first attempt is confirmed, and raise a ticket with the bank operations desk if timeouts continue after 10 minutes.'
       WHEN BLOCKER_TYPE = 'Network link down' THEN 'move the desk tablet to the backup mobile data SIM, confirm pending applications were saved, and escalate to field support if both links are down.'
       WHEN BLOCKER_TYPE = 'Membership form incomplete' THEN 'walk the recipient through the missing fields of the cooperative membership form and attach it to the account application before submitting.'
       ELSE 'review the blocker against the site profile and escalate if unexplained.'
     END
  || ' Step 3: if the site eKYC error rate exceeds 5% or the average onboarding time exceeds 30 minutes after the fix, keep the ticket open and request a site review. '
  || 'Step 4: record the outcome; if the application was abandoned or the same-day SLA was missed, log it for the weekly inclusion programme report and schedule a follow-up contact.' AS CONTENT
FROM types;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.ONBOARDING_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, BLOCKER_TYPE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, BLOCKER_TYPE, CONTENT FROM SEARCH.BLOCKER_DOCS);

-- ---------- eKYC error rate anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.EKYC_ERROR_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, EKYC_ERROR_PCT::FLOAT AS EKYC_ERROR
FROM RAW.SITE_DAILY;
CREATE OR REPLACE VIEW ML.EKYC_ERROR_TRAIN AS
SELECT * FROM ML.EKYC_ERROR_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.EKYC_ERROR_SERIES);
CREATE OR REPLACE VIEW ML.EKYC_ERROR_DETECT AS
SELECT * FROM ML.EKYC_ERROR_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.EKYC_ERROR_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.EKYC_ERROR_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.EKYC_ERROR_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'EKYC_ERROR',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.EKYC_ERROR_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS EKYC_ERROR, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.EKYC_ERROR_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.EKYC_ERROR_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'EKYC_ERROR'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.INCLUSION_ANALYTICS
  TABLES (
    sites AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'sites', 'pickup sites')
      COMMENT = 'One row per fictional remittance pickup site in a Philippine city, 90-day totals',
    risk AS ML.DROPOUT_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day abandoned-application probability per site',
    blockers AS CURATED.BLOCKER_SUMMARY PRIMARY KEY (BLOCKER_TYPE)
      COMMENT = 'Onboarding blockers, abandoned applications and same-day SLA breaches by blocker type, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Programme-wide totals per day'
  )
  RELATIONSHIPS (risk_site AS risk (ENTITY_ID) REFERENCES sites)
  FACTS (
    sites.blockers_f AS BLOCKER_COUNT,
    sites.dropouts_f AS DROPOUT_COUNT,
    sites.breaches_f AS SLA_BREACH_COUNT,
    sites.pickups_f AS PICKUP_COUNT,
    sites.payout_f AS PAYOUT_PHP,
    sites.opened_f AS ACCOUNTS_OPENED,
    sites.followup_due_f AS FOLLOWUP_DUE,
    sites.followup_done_f AS FOLLOWUP_COMPLETED,
    risk.dropout_prob_f AS DROPOUT_PROB_7D,
    blockers.type_blockers_f AS BLOCKER_COUNT,
    blockers.type_dropouts_f AS DROPOUT_COUNT,
    blockers.type_breaches_f AS SLA_BREACH_COUNT,
    blockers.type_payout_f AS EXPOSED_PAYOUT_PHP,
    daily.day_blockers_f AS BLOCKER_COUNT,
    daily.day_dropouts_f AS DROPOUT_COUNT,
    daily.day_payout_f AS PAYOUT_PHP
  )
  DIMENSIONS (
    sites.site_id AS ENTITY_ID WITH SYNONYMS = ('site', 'site code', 'entity'),
    sites.site_name AS ENTITY_NAME,
    sites.city AS REGION WITH SYNONYMS = ('city', 'region', 'location')
      COMMENT = 'Philippine city of the site',
    sites.site_format AS CATEGORY WITH SYNONYMS = ('format', 'site type', 'partner type'),
    sites.risk_tier AS RISK_TIER COMMENT = 'Site operational risk tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    blockers.blocker_type AS BLOCKER_TYPE WITH SYNONYMS = ('blocker', 'blocker reason', 'onboarding issue'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    sites.site_total AS COUNT(sites.site_id)
      WITH SYNONYMS = ('number of sites', 'number of entities', 'how many sites'),
    sites.blocker_free_rate AS 100 * (SUM(sites.pickups_f) - SUM(sites.blockers_f)) / NULLIF(SUM(sites.pickups_f), 0)
      WITH SYNONYMS = ('blocker-free pickup rate', 'blocker-free rate')
      COMMENT = 'Pickups not touched by an onboarding blocker / remittance pickups',
    sites.dropout_share_pct AS 100 * SUM(sites.dropouts_f) / NULLIF(SUM(sites.blockers_f), 0)
      COMMENT = 'Abandoned applications / onboarding blockers',
    sites.blockers_logged AS SUM(sites.blockers_f) WITH SYNONYMS = ('blockers', 'blocker volume'),
    sites.abandoned_applications AS SUM(sites.dropouts_f) WITH SYNONYMS = ('dropouts', 'abandoned applications'),
    sites.sla_breaches AS SUM(sites.breaches_f) WITH SYNONYMS = ('same-day SLA breaches', 'SLA misses'),
    sites.pickups_total AS SUM(sites.pickups_f) WITH SYNONYMS = ('remittance pickups', 'pickups'),
    sites.total_payout_php AS SUM(sites.payout_f) WITH SYNONYMS = ('payouts', 'payout value in PHP'),
    sites.accounts_opened_total AS SUM(sites.opened_f) WITH SYNONYMS = ('accounts opened', 'savings accounts opened'),
    sites.conversion_pct AS 100 * SUM(sites.opened_f) / NULLIF(SUM(sites.pickups_f), 0)
      WITH SYNONYMS = ('pickup-to-account conversion', 'conversion rate')
      COMMENT = 'Savings accounts opened / remittance pickups',
    sites.followup_completion_rate AS 100 * SUM(sites.followup_done_f) / NULLIF(SUM(sites.followup_due_f), 0)
      COMMENT = 'Dormant-account follow-ups completed / follow-ups due',
    risk.avg_dropout_prob AS AVG(risk.dropout_prob_f),
    blockers.type_blockers AS SUM(blockers.type_blockers_f),
    blockers.type_dropouts AS SUM(blockers.type_dropouts_f),
    blockers.type_breaches AS SUM(blockers.type_breaches_f),
    blockers.type_dropout_share_pct AS 100 * SUM(blockers.type_dropouts_f) / NULLIF(SUM(blockers.type_blockers_f), 0),
    daily.daily_blockers AS SUM(daily.day_blockers_f),
    daily.daily_dropouts AS SUM(daily.day_dropouts_f),
    daily.daily_payout_php AS SUM(daily.day_payout_f)
  )
  COMMENT = 'Synthetic Philippine remittance inclusion programme analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.INCLUSION_OPS_AGENT
  COMMENT = 'Inclusion programme operations assistant over a synthetic Philippine remittance pickup site network'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give site IDs and numbers with units (PHP, %)."
  orchestration: "Use site_analyst for sites, cities, site formats, remittance pickups, payouts, savings accounts opened, onboarding blockers, abandoned applications, same-day SLA breaches, dormant-account follow-up completion, blocker types and abandoned-application risk. Use sop_search for onboarding-blocker procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: site_analyst
      description: "Site count, remittance pickups, payouts in PHP, savings accounts opened, onboarding blockers, abandoned applications, same-day SLA breaches, blocker-free pickup rate, dormant-account follow-up completion, blocker types and abandoned-application risk scores by site, city and format"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic onboarding-blocker handling SOPs by site format and blocker type"
tool_resources:
  site_analyst:
    semantic_view: __DEMO_DB__.APP.INCLUSION_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.ONBOARDING_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;
-- ---------- Live-blocker alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), SITE_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, AMOUNT_PHP FLOAT, ONBOARD_MINUTES FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION PH_REMITTANCE_INCLUSION_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (SITE_ID, EVENT_TS, AMOUNT_PHP, ONBOARD_MINUTES, SOP_HINT)
    SELECT p.SITE_ID, p.EVENT_TS, p.AMOUNT_PHP, p.ONBOARD_MINUTES,
           'Check ' || r.CATEGORY || ' onboarding SOPs; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_PICKUPS p
    JOIN RAW.SITES r ON r.ID = p.SITE_ID
    LEFT JOIN ML.DROPOUT_RISK_SCORES s ON s.ENTITY_ID = p.SITE_ID
    WHERE p.STATUS = 'BLOCKER'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SITE_ID = p.SITE_ID AND l.EVENT_TS = p.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('PH_REMITTANCE_INCLUSION_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Site onboarding blocker alert',
      'New live site blockers logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_BLOCKER_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_PICKUPS p
    WHERE p.STATUS = 'BLOCKER'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SITE_ID = p.SITE_ID AND l.EVENT_TS = p.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.BLOCKER_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.DROPOUT_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.DROPOUT_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.DROPOUT_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'SITE_TENURE_YEARS', SITE_TENURE_YEARS,
             'EKYC_ERROR_PCT', EKYC_ERROR_PCT, 'AVG_ONBOARD_MIN', AVG_ONBOARD_MIN,
             'EKYC_ERROR_7D', EKYC_ERROR_7D, 'DROPOUT_30D', DROPOUT_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:DROPOUT::FLOAT, 4) AS DROPOUT_PROB_7D,
         CASE WHEN PRED:probability:DROPOUT::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:DROPOUT::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
