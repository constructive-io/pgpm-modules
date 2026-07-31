-- Verify schemas/metaschema_public/tables/derives/table on pg

BEGIN;

SELECT
    id,
    database_id,
    table_id,
    source_table_id,
    kind,
    include_mutations,
    policy_prefix
FROM metaschema_public.derives
WHERE FALSE;

ROLLBACK;
