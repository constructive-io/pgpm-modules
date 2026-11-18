-- Revert schemas/metaschema_modules_public/tables/db_usage_module/alterations/add_read_usage_period_functions from pg

BEGIN;

ALTER TABLE metaschema_modules_public.db_usage_module
  DROP COLUMN IF EXISTS read_db_table_stats_usage_period_function,
  DROP COLUMN IF EXISTS read_db_query_stats_usage_period_function;

COMMIT;
