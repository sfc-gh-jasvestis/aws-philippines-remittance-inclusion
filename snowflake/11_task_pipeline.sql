-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Financial Inclusion & Micro-lending Analytics
-- ============================================================================
USE DATABASE FINANCIAL_INCLUSION;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_REFRESH_FEATURES
  WAREHOUSE = INCLUSION_WH
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
  COMMENT = 'Refresh alternative credit features from latest data'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_SCORE_APPLICANTS
  WAREHOUSE = INCLUSION_WH
  AFTER APP.TASK_REFRESH_FEATURES
  COMMENT = 'Score pending loan applications'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_NOTIFY_APPROVALS
  WAREHOUSE = INCLUSION_WH
  AFTER APP.TASK_SCORE_APPLICANTS
  COMMENT = 'Send SES notifications for approved applications'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_NOTIFY_APPROVALS RESUME;
ALTER TASK APP.TASK_SCORE_APPLICANTS RESUME;
ALTER TASK APP.TASK_REFRESH_FEATURES RESUME;
