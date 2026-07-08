-- Verify schemas/metaschema_modules_public/tables/db_usage_module/table on pg

SELECT id, database_id, schema_id, private_schema_id,
       retention, premake,
       prefix
FROM metaschema_modules_public.db_usage_module
WHERE FALSE;
