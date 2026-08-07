-- Verify schemas/metaschema_public/tables/primary_key_constraint/table on pg

BEGIN;

SELECT assert_table('metaschema_public.primary_key_constraint'::regclass);

ROLLBACK;
