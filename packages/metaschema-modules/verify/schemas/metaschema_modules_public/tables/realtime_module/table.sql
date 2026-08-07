-- Verify schemas/metaschema_modules_public/tables/realtime_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.realtime_module'::regclass);

ROLLBACK;
