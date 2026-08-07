-- Verify schemas/metaschema_public/tables/function/table on pg

BEGIN;

SELECT assert_table('metaschema_public.function'::regclass);

ROLLBACK;
