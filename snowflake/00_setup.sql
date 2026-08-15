-- ============================================================================
-- Financial Inclusion & Micro-lending Analytics
-- 46% of Filipino adults remain unbanked — Snowflake enables alternative credit scoring using remittance history and digital behavior, expanding lending access to millions through ML.CLASSIFICATION on non-traditional data.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS FINANCIAL_INCLUSION;
CREATE WAREHOUSE IF NOT EXISTS INCLUSION_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE FINANCIAL_INCLUSION;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE INCLUSION_WH;
