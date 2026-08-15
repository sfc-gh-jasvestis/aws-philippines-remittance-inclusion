-- ============================================================================
-- 01_MARKETPLACE_INSTALL.SQL — Install marketplace data for Financial Inclusion & Micro-lending Analytics
-- ============================================================================
USE DATABASE FINANCIAL_INCLUSION;
USE SCHEMA RAW;

-- Free listings to install from Snowflake Marketplace:
-- Install: Snowflake Public Data (Free)
--   https://app.snowflake.com/marketplace/listing/GZTSZ290BV255

-- Paid listing (mock): CEIC ASEAN Macro
--   Real data: https://app.snowflake.com/marketplace/listing/GZTSZRC7HPI
--   Using mock table: BSP_INCLUSION_DATA
CREATE TABLE IF NOT EXISTS RAW.BSP_INCLUSION_DATA (
  ID INT AUTOINCREMENT, DATA VARIANT, LOADED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

