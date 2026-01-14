-- Verify schemas/metaschema_modules_public/tables/table_module/table on pg

BEGIN;

SELECT
    id,
    database_id,
    private_schema_id,
    table_id,
    node_type,
    data,
    fields
FROM metaschema_modules_public.table_module
WHERE FALSE;

ROLLBACK;
