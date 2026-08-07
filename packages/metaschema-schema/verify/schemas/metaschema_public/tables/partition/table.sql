-- Verify schemas/metaschema_public/tables/partition/table on pg

BEGIN;

SELECT assert_table('metaschema_public.partition'::regclass);

ROLLBACK;
