-- Verify schemas/metaschema_public/tables/trigger_function/table on pg

BEGIN;

SELECT assert_table('metaschema_public.trigger_function'::regclass);

ROLLBACK;
