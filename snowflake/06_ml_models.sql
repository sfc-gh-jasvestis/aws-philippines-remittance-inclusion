-- ============================================================================
-- 06_ML_MODELS.SQL — ML Functions for Financial Inclusion & Micro-lending Analytics
-- ============================================================================
USE DATABASE FINANCIAL_INCLUSION;
USE SCHEMA ML;

-- ML.CLASSIFICATION: ALT_CREDIT_SCORER
CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION ML.ALT_CREDIT_SCORER(
  INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'CURATED.ALT_CREDIT_FEATURES'),
  TARGET_COLNAME => 'DEFAULT_30D'
);

-- ML.TOP_INSIGHTS: CREDIT_DRIVERS
-- Call: SELECT * FROM TABLE(ML.CREDIT_DRIVERS!GET_INSIGHTS(INPUT_DATA => ...));

