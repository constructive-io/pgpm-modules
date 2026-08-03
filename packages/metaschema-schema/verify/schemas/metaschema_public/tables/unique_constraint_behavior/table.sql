-- Verify schemas/metaschema_public/tables/unique_constraint_behavior/table on pg

BEGIN;

SELECT
    id,
    database_id,
    unique_constraint_id,
    modifier,
    scope,
    sort_order
FROM metaschema_public.unique_constraint_behavior
WHERE FALSE;

ROLLBACK;
