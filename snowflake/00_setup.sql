-- Generated from generator/demo_specs/aws-philippines-remittance-inclusion.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-philippines-remittance-inclusion
-- This is the schema that is actually deployed for PH_REMITTANCE_INCLUSION.

-- PH_REMITTANCE_INCLUSION  (Financial Inclusion & Micro-lending Analytics)
-- generated from generator/demo_specs/aws-philippines-remittance-inclusion.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS PH_REMITTANCE_INCLUSION;
CREATE SCHEMA IF NOT EXISTS PH_REMITTANCE_INCLUSION.RAW;
CREATE SCHEMA IF NOT EXISTS PH_REMITTANCE_INCLUSION.CURATED;
CREATE SCHEMA IF NOT EXISTS PH_REMITTANCE_INCLUSION.APP;
USE DATABASE PH_REMITTANCE_INCLUSION;

-- 5 real regions; entity names carry their region so the two always agree
