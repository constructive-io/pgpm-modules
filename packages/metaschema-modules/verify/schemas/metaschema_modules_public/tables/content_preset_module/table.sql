-- Verify schemas/metaschema_modules_public/tables/content_preset_module/table on pg

BEGIN;

SELECT id, database_id, public_schema_id, private_schema_id, merkle_store_module_id, store_name, scope, prefix
  FROM metaschema_modules_public.content_preset_module
 WHERE FALSE;

ROLLBACK;
