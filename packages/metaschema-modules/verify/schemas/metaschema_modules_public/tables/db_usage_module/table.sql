-- Verify schemas/metaschema_modules_public/tables/db_usage_module/table on pg

SELECT id, database_id, schema_id, private_schema_id,
       table_stats_log_table_id, table_stats_log_table_name,
       table_stats_daily_table_id, table_stats_daily_table_name,
       query_stats_log_table_id, query_stats_log_table_name,
       query_stats_daily_table_id, query_stats_daily_table_name,
       retention, scope, prefix
FROM metaschema_modules_public.db_usage_module
WHERE FALSE;
