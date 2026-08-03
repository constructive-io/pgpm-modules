-- Verify schemas/metaschema_public/tables/field_behavior/table on pg

BEGIN;

SELECT
    id,
    database_id,
    field_id,
    modifier,
    scope,
    sort_order
FROM metaschema_public.field_behavior
WHERE FALSE;

ROLLBACK;
