-- Verify schemas/metaschema_public/tables/table_behavior/table on pg

BEGIN;

SELECT
    id,
    database_id,
    table_id,
    modifier,
    scope,
    sort_order
FROM metaschema_public.table_behavior
WHERE FALSE;

ROLLBACK;
