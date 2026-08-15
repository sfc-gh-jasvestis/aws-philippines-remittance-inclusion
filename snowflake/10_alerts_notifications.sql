-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Financial Inclusion & Micro-lending Analytics
-- ============================================================================
USE DATABASE FINANCIAL_INCLUSION;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_philippines_remittance_inclusion_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('jonathan.asvestis@snowflake.com');

-- Alert: DEFAULT_SPIKE_ALERT
CREATE OR REPLACE ALERT APP.DEFAULT_SPIKE_ALERT
  WAREHOUSE = INCLUSION_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Default rate exceeding threshold for loan vintage'
IF (EXISTS (
  SELECT 1 FROM CURATED.ALT_CREDIT_FEATURES
  WHERE 1=1 -- Condition: 30D_DEFAULT_RATE > 5% for any vintage
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_remittance_inclusion_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Financial Inclusion & Micro-lending Analytics: Default rate exceeding threshold for loan vintage',
    'Default rate exceeding threshold for loan vintage'
  );

ALTER ALERT APP.DEFAULT_SPIKE_ALERT RESUME;

-- Alert: MODEL_DRIFT_ALERT
CREATE OR REPLACE ALERT APP.MODEL_DRIFT_ALERT
  WAREHOUSE = INCLUSION_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Credit scoring model stability index degrading'
IF (EXISTS (
  SELECT 1 FROM CURATED.ALT_CREDIT_FEATURES
  WHERE 1=1 -- Condition: PSI > 0.2 for credit model
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_remittance_inclusion_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Financial Inclusion & Micro-lending Analytics: Credit scoring model stability index degrading',
    'Credit scoring model stability index degrading'
  );

ALTER ALERT APP.MODEL_DRIFT_ALERT RESUME;

