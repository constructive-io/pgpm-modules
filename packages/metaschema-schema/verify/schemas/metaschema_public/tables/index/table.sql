-- Verify schemas/metaschema_public/tables/index/table on pg

BEGIN;

SELECT assert_table('metaschema_public.index'::regclass);

ROLLBACK;
