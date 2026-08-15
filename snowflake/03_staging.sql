-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Financial Inclusion & Micro-lending Analytics
-- Country: PHILIPPINES | Currency: PHP
-- ============================================================================
USE DATABASE FINANCIAL_INCLUSION;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- BORROWER_PROFILES: 380,000 rows — Micro-loan applicants with demographic and KYC data
-- REMITTANCE_HISTORY: 2,800,000 rows — 12 months remittance receiving patterns (frequency, amount, source)
-- WALLET_BEHAVIOR: 4,200,000 rows — E-wallet transaction patterns (top-ups, bills, savings)
-- TELCO_SIGNALS: 1,500,000 rows — Mobile usage data (airtime load, data usage, payment history)
-- LOAN_PORTFOLIO: 145,000 rows — Active and historical loan records
-- REPAYMENT_RECORDS: 870,000 rows — Loan repayment history with status (on-time, late, default)
-- BSP_INCLUSION_DATA: 82 rows — BSP financial inclusion survey data by region
