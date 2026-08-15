-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Financial Inclusion & Micro-lending Analytics
-- ============================================================================
USE DATABASE FINANCIAL_INCLUSION;
USE SCHEMA CURATED;

-- ALT_CREDIT_FEATURES: Alternative credit features from remittance, wallet, and telco data
-- Source: BORROWER_PROFILES, REMITTANCE_HISTORY, WALLET_BEHAVIOR, TELCO_SIGNALS
CREATE OR REPLACE DYNAMIC TABLE CURATED.ALT_CREDIT_FEATURES
  TARGET_LAG = '5 minutes'
  WAREHOUSE = INCLUSION_WH
AS
SELECT * FROM RAW.BORROWER_PROFILES;
-- TODO: Replace with actual join/aggregation logic per demo

-- PORTFOLIO_HEALTH: Real-time loan portfolio metrics (default rate, PAR, vintage analysis)
-- Source: LOAN_PORTFOLIO, REPAYMENT_RECORDS
CREATE OR REPLACE DYNAMIC TABLE CURATED.PORTFOLIO_HEALTH
  TARGET_LAG = '5 minutes'
  WAREHOUSE = INCLUSION_WH
AS
SELECT * FROM RAW.LOAN_PORTFOLIO;
-- TODO: Replace with actual join/aggregation logic per demo

-- INCLUSION_METRICS: Financial inclusion KPIs by region and demographic
-- Source: BORROWER_PROFILES, LOAN_PORTFOLIO, BSP_INCLUSION_DATA
CREATE OR REPLACE DYNAMIC TABLE CURATED.INCLUSION_METRICS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = INCLUSION_WH
AS
SELECT * FROM RAW.BORROWER_PROFILES;
-- TODO: Replace with actual join/aggregation logic per demo

-- MODEL_MONITORING: Credit model performance tracking (PSI, KS, Gini over time)
-- Source: LOAN_PORTFOLIO, REPAYMENT_RECORDS
CREATE OR REPLACE DYNAMIC TABLE CURATED.MODEL_MONITORING
  TARGET_LAG = '5 minutes'
  WAREHOUSE = INCLUSION_WH
AS
SELECT * FROM RAW.LOAN_PORTFOLIO;
-- TODO: Replace with actual join/aggregation logic per demo

