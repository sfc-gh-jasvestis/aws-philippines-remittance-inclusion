-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Financial Inclusion & Micro-lending Analytics
-- ============================================================================
USE DATABASE FINANCIAL_INCLUSION;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.INCLUSION_INTELLIGENCE_AGENT
  COMMENT = 'Financial Inclusion & Micro-lending Analytics AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'FINANCIAL_INCLUSION.APP.INCLUSION_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'FINANCIAL_INCLUSION.SEARCH.BSP_REGULATION_SEARCH', TOOL_DESCRIPTION => 'Search documents for Remittances & Fintech information')
  )
  SYSTEM_PROMPT = 'You are the Financial Inclusion Intelligence Agent for a Philippine micro-lender serving 380K borrowers, 65% previously unbanked, using alternative data for credit scoring.';
