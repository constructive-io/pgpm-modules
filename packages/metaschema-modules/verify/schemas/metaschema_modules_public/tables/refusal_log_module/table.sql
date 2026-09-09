-- Verify schemas/metaschema_modules_public/tables/refusal_log_module/table on pg

SELECT id, database_id, schema_id, private_schema_id,
       log_table_id, summary_table_id,
       log_retention, summary_retention,
       record_refusals_function, rollup_refusal_usage_summary_function,
       prefix
FROM metaschema_modules_public.refusal_log_module
WHERE FALSE;
