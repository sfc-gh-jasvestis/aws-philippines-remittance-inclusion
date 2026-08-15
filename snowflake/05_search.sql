-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Financial Inclusion & Micro-lending Analytics
-- ============================================================================
USE DATABASE FINANCIAL_INCLUSION;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.BSP_REGULATION_SEARCH
  ON REGULATION_TEXT
  ATTRIBUTES REGULATION_TYPE, EFFECTIVE_DATE, SECTOR
  WAREHOUSE = INCLUSION_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.BSP_INCLUSION_DATA
);
