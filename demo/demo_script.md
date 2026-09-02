# Financial Inclusion & Micro-lending Analytics

**Philippines - Remittances & Fintech**
Use case: Financial Inclusion

> 46% of Filipino adults remain unbanked — Snowflake enables alternative credit scoring using remittance history and digital behavior, expanding lending access to millions through ML.CLASSIFICATION on non-traditional data.

## Why Snowflake

Snowflake builds alternative credit scores using remittance patterns, e-wallet behavior, and telco data via ML.CLASSIFICATION, enabling micro-lending decisions for the unbanked — replacing expensive SageMaker pipelines with native SQL ML

- **ML.CLASSIFICATION for alternative credit scoring** - Only demo using native Snowflake ML for credit decisioning on non-traditional data
- **Alternative data (remittance + wallet + telco)** - Three non-traditional data sources combined for credit assessment
- **SES notification for loan decisions** - End-to-end: score → decide → notify borrower via email
- **Financial inclusion focus** - Specifically targets the 46% unbanked Filipino population
- **BSP regulatory compliance** - Cortex Complete generates explainable decisions for BSP audit requirements
- **Model monitoring with PSI tracking** - Dynamic Table monitors model stability — alerts before drift causes losses

## What is deployed

| | |
|---|---|
| Database | `PH_REMITTANCE_INCLUSION` |
| Service | `PH_REMITTANCE_INCLUSION_APP` |
| Compute pool | `SEA_DEMOS_PHILIPPINES_POOL` |
| Dimension table | `RAW.BSP_INCLUSION_DATA` (20 rows) |
| Fact table | `RAW.WALLET_BEHAVIOR` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | PHP (₱) |

Regions in play: Metro Manila, Cebu, Davao, Pampanga, Iloilo
Segments: First-Time Borrower, OFW Family, Micro Merchant, Farmer

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh PH_REMITTANCE_INCLUSION
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Unbanked Onboarded | `2.4M` | total across Bsp Inclusion Data |
| Agent Network | `42K` | total across Bsp Inclusion Data |
| Rural Coverage | `78%` | average per event |
| Avg Remittance | `₱8,400` | average per event |
| Agent Uptime | `94%` | average per event |
| Liquidity Issues | `42/day` | average per event |
| Revenue/Agent | `₱18K/mo` | average per event |


## Demo flow

1. Executive Cockpit
2. Alt Credit Scoring
3. Portfolio Health
4. Ask AI
5. Architecture & Data

## Talking points

- **380,000** - borrowers served (65% previously unbanked)
- **₱8.2B** - total loan portfolio outstanding
- **3.8%** - overall default rate (below 5% target)
- **42% more approvals** - vs traditional bureau scoring
- **0.62 Gini** - coefficient for alt-credit model
- **51M Filipinos** - unbanked — addressable market

## Business impact

- 46% of Filipino adults (51M people) remain unbanked as of 2023 (BSP Financial Inclusion Survey)
- Alternative credit scoring expands lending access by 40-60% in emerging markets (World Bank)
- Philippine micro-lending market grew 45% in 2023 driven by digital lenders (SEC Philippines)
- ML-based credit scoring reduces default rates 20-30% vs traditional scorecards (McKinsey Banking)

---
Generated from `generator/demo_specs/aws-philippines-remittance-inclusion.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-philippines-remittance-inclusion` instead.
