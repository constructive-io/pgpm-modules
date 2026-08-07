-- Verify schemas/metaschema_public/tables/policy/table on pg

BEGIN;

SELECT assert_table('metaschema_public.policy'::regclass);

ROLLBACK;
