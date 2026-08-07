
BEGIN;

SELECT assert_table('metaschema_public.table'::regclass);

ROLLBACK;
