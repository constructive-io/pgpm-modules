-- Deploy schemas/metaschema_modules_public/tables/db_usage_module/alterations/add_read_usage_period_functions to pg

-- requires: schemas/metaschema_modules_public/tables/db_usage_module/table

BEGIN;

-- Output: the generated typed period readers of the two summary planes
-- (<private>.read_db_table_stats_usage_period / read_db_query_stats_usage_period),
-- which the billing bridge calls by name instead of assembling SQL.
ALTER TABLE metaschema_modules_public.db_usage_module
  ADD COLUMN IF NOT EXISTS read_db_table_stats_usage_period_function text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS read_db_query_stats_usage_period_function text NOT NULL DEFAULT '';

COMMIT;
