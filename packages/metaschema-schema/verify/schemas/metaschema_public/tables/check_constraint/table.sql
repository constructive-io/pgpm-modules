-- Verify schemas/metaschema_public/tables/check_constraint/table on pg

BEGIN;

SELECT assert_table('metaschema_public.check_constraint'::regclass);

ROLLBACK;
