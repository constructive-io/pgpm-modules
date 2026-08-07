-- Verify schemas/metaschema_public/tables/exclusion_constraint/table on pg

BEGIN;

SELECT assert_table('metaschema_public.exclusion_constraint'::regclass);

ROLLBACK;
