-- Verify schemas/metaschema_public/tables/view_behavior/table on pg

BEGIN;

SELECT
    id,
    database_id,
    view_id,
    modifier,
    scope,
    sort_order
FROM metaschema_public.view_behavior
WHERE FALSE;

ROLLBACK;
