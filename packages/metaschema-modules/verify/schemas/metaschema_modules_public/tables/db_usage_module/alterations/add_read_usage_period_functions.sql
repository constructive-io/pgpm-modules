-- Verify schemas/metaschema_modules_public/tables/db_usage_module/alterations/add_read_usage_period_functions on pg

BEGIN;

SELECT read_db_table_stats_usage_period_function, read_db_query_stats_usage_period_function
  FROM metaschema_modules_public.db_usage_module WHERE FALSE;

ROLLBACK;
