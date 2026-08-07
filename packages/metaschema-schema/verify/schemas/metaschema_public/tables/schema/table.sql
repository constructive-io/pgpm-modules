-- Verify schemas/metaschema_public/tables/schema/table on pg

BEGIN;

SELECT assert_table('metaschema_public.schema'::regclass);

ROLLBACK;
