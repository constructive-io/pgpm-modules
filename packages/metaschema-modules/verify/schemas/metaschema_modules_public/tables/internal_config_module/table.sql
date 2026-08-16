-- Verify schemas/metaschema_modules_public/tables/internal_config_module/table on pg

BEGIN;

SELECT id, database_id, schema_id, internal_config_table_id, scope, prefix
  FROM metaschema_modules_public.internal_config_module
 WHERE FALSE;

ROLLBACK;
