-- Verify schemas/metaschema_modules_public/tables/user_settings_module/table on pg

BEGIN;

SELECT
    id,
    database_id,
    schema_id,
    private_schema_id,
    table_id,
    owner_table_id,
    table_name
FROM metaschema_modules_public.user_settings_module
WHERE FALSE;

ROLLBACK;
