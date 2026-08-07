-- Verify schemas/metaschema_public/tables/table_grant/table on pg

BEGIN;

SELECT assert_table('metaschema_public.table_grant'::regclass);

ROLLBACK;
