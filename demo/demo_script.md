# Philippines Remittance Inclusion Operations

**Philippines - Remittance Pickup Sites and Savings Account Onboarding**
Use case: onboarding blockers, abandoned applications, same-day service levels, dormant-account follow-ups and partner controls

> Onboarding monitoring for 40 remittance pickup sites in the inclusion programme of a fictional Philippine rural bank in 5 cities: dynamic tables, a holdout-evaluated abandoned-application classifier, a blocker-volume forecast and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile pickups, savings accounts opened, onboarding blockers, abandoned applications, same-day SLA breaches and dormant-account follow-up completion from RAW site data, with checks in `run_core.py`
- **Abandoned-application classification** gives a holdout-evaluated next-7-day probability per site
- **Blocker forecast** projects 14 days of programme-wide blocker volume with prediction intervals, for onboarding-desk staffing
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live pickups**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.SITES` (40 rows) |
| Fact table | `RAW.SITE_DAILY` (3,600 site-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `BLOCKER_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.DROPOUT_RISK_SCORES`, `ML.DROPOUT_RISK_HOLDOUT_METRICS`, `ML.BLOCKER_FORECAST`, `ML.EKYC_ERROR_ANOMALIES` |

Cities: Batangas City, Tacloban City, General Santos City, Angeles City, Naga City (PHP).
Formats: Pawnshop branch, Rural bank branch, Cooperative office, Money transfer kiosk, Mall service desk.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Blocker-Free Pickup Rate | 99.93% |
| Onboarding Blockers | 607 |
| Abandoned-Application Blockers | 207 |
| Blocker Dropout Rate | 34.1% |
| Same-Day SLA Breaches | 79 |
| Remittance Payouts (PHP M) | 6,512 |
| Remittance Pickups | 843,634 |
| Dormant-Account Follow-Up Completion | 73.2% |
| Sites Monitored | 40 |
| Partner Document Coverage | 72.7% |
| Partner Documents Pending | 20 |
| Savings Accounts Opened | 24,629 |
| Pickup-to-Account Conversion | 2.92% |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily blockers against abandoned applications, blockers and dropouts by blocker type, site table
2. Predictive: holdout metrics, risk bands, 14-day blocker forecast, eKYC error-rate anomalies
3. Controls: dormant-account follow-up completion, partner document coverage and pending documents, follow-up completion against abandoned applications, then generate the action memo
4. Live Pickups: run `CALL APP.SIMULATE_PICKUPS(20)` (Snowflake only) or `python aws/publish_pickups.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_BLOCKER_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 24,629 of 843,634 remittance pickups (2.92%) turned into a basic savings account; the 607 onboarding blockers are where desk time goes, and 34.1% of them end in abandoned applications.
- Proof of address gap produces the most abandoned applications (69 of 136 blockers). Area power interruptions hit every site in a city at once and always resolve.
- The risk model is evaluated on a time-based holdout: precision 0.43 and recall 0.28 at 0.5, against a 0.250 base rate. Present it as triage, not a verdict on any site or recipient.
- Area power interruptions are excluded from model training, because they are not site-driven.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
