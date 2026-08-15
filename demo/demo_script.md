# Demo Script: Financial Inclusion & Micro-lending Analytics
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake builds alternative credit scores using remittance patterns, e-wallet behavior, and telco data via ML.CLASSIFICATION, enabling micro-lending decisions for the unbanked — replacing expensive SageMaker pipelines with native SQL ML"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Rosario Elena Madrigal** | Chief Lending Officer | React App (SPCS) | Portfolio quality, approval rates, default rates, regulatory compliance, financial inclusion metrics |
| **Carlo Miguel Araneta** | Credit Risk Data Scientist | Amazon QuickSight | Model performance, feature importance, score calibration, bias monitoring |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 7 tables | BORROWER_PROFILES (380000), REMITTANCE_HISTORY (2800000), WALLET_BEHAVIOR (4200000), TELCO_SIGNALS (1500000), LOAN_PORTFOLIO (145000), REPAYMENT_RECORDS (870000), BSP_INCLUSION_DATA (82) |
| **CURATED** | 4 Dynamic Tables | ALT_CREDIT_FEATURES, PORTFOLIO_HEALTH, INCLUSION_METRICS, MODEL_MONITORING |
| **ML** | ML.CLASSIFICATION + ML.TOP_INSIGHTS | Forecasting + anomaly detection |
| **AI** | COMPLETE, AI_CLASSIFY | Classification + extraction |
| **Search** | Cortex Search | 82 documents indexed |
| **Agent** | INCLUSION_INTELLIGENCE_AGENT | Semantic View + Search tools |


---

## The Story

46% of Filipino adults — 51 million people — have no bank account and no traditional credit score. They're invisible to conventional lenders. But they receive remittances, use e-wallets, and pay mobile bills. A Philippine micro-lender uses these alternative data signals to build credit scores for the unbanked, processing 380,000 loan applications using ML.CLASSIFICATION on remittance frequency, wallet behavior, and telco payment patterns.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "380,000 borrowers served — 65% previously unbanked Filipinos."

**Action**: Point at 380K borrowers served KPI

### [0:45–1:30] ALT CREDIT SCORING

**Show**: Alt Credit Scoring tab

> "ML.CLASSIFICATION trained on 145K historical loans — Gini coefficient 0.62."

**Action**: Show model performance metrics (Gini, KS)

### [1:30–2:15] PORTFOLIO HEALTH

**Show**: Portfolio Health tab

> "Default rate: 3.8% overall, but varying by region — Mindanao at 4.9% (approaching threshold)."

**Action**: Show default rate by region map

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Rosario asks: 'How many unbanked borrowers did we serve in Visayas this quarter?'"

**Action**: Type: 'Unbanked borrowers in Visayas this quarter?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Three alternative data sources → Dynamic Tables → ML.CLASSIFICATION → scoring in minutes."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **ML.CLASSIFICATION for alternative credit scoring** — Only demo using native Snowflake ML for credit decisioning on non-traditional data
2. **Alternative data (remittance + wallet + telco)** — Three non-traditional data sources combined for credit assessment
3. **SES notification for loan decisions** — End-to-end: score → decide → notify borrower via email
4. **Financial inclusion focus** — Specifically targets the 46% unbanked Filipino population
5. **BSP regulatory compliance** — Cortex Complete generates explainable decisions for BSP audit requirements
6. **Model monitoring with PSI tracking** — Dynamic Table monitors model stability — alerts before drift causes losses


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM FINANCIAL_INCLUSION.RAW.BORROWER_PROFILES` → 380000
- [ ] `SELECT COUNT(*) FROM FINANCIAL_INCLUSION.RAW.REMITTANCE_HISTORY` → 2800000
- [ ] `SELECT COUNT(*) FROM FINANCIAL_INCLUSION.RAW.LOAN_PORTFOLIO WHERE BORROWER_UNBANKED = TRUE` → ~247000

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM FINANCIAL_INCLUSION.ML.ALT_CREDIT_CLASSIFICATION_RESULTS` → >0
- [ ] `SELECT COUNT(*) FROM FINANCIAL_INCLUSION.ML.CREDIT_TOP_INSIGHTS` → >0

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM FINANCIAL_INCLUSION.AI.BORROWER_SEGMENT_CLASSIFICATION` → 380000

