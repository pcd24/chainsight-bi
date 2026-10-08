-- 01_setup/01_schemas.sql
-- Layered schemas. Re-runnable: dropping a schema removes everything built from it.
CREATE SCHEMA IF NOT EXISTS raw;        -- exact copy of source files (all text, dirty)
CREATE SCHEMA IF NOT EXISTS staging;    -- typed, trimmed, de-duplicated, validated
CREATE SCHEMA IF NOT EXISTS dw;         -- star schema (dimensions + facts) read by Power BI
CREATE SCHEMA IF NOT EXISTS analytics;  -- reporting views and business-question queries
CREATE SCHEMA IF NOT EXISTS dq;         -- data-quality results

COMMENT ON SCHEMA raw IS 'Source data exactly as received. Never edited. All columns TEXT.';
COMMENT ON SCHEMA staging IS 'Cleaned and typed data. Bad rows are logged in staging.rejects.';
COMMENT ON SCHEMA dw IS 'Dimensional warehouse (star schema). Only trusted data lives here.';
COMMENT ON SCHEMA analytics IS 'Views for Power BI and SQL analytical questions.';
COMMENT ON SCHEMA dq IS 'Data-quality check results.';
