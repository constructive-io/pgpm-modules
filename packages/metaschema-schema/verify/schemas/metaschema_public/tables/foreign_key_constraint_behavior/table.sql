-- Verify schemas/metaschema_public/tables/foreign_key_constraint_behavior/table on pg

BEGIN;

SELECT
    id,
    database_id,
    foreign_key_constraint_id,
    modifier,
    scope,
    sort_order
FROM metaschema_public.foreign_key_constraint_behavior
WHERE FALSE;

ROLLBACK;
