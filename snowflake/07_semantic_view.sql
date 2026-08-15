-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Financial Inclusion & Micro-lending Analytics
-- ============================================================================
USE DATABASE FINANCIAL_INCLUSION;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.INCLUSION_ANALYTICS
  COMMENT = 'Financial inclusion, alternative credit scoring, and micro-lending analytics'
AS
  TABLES (
    CURATED.ALT_CREDIT_FEATURES AS alt_credit_features,CURATED.PORTFOLIO_HEALTH AS portfolio_health,CURATED.INCLUSION_METRICS AS inclusion_metrics,CURATED.MODEL_MONITORING AS model_monitoring
  );
