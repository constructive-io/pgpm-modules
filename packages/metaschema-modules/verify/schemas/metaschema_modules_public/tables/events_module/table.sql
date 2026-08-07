-- Verify schemas/metaschema_modules_public/tables/events_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.events_module'::regclass);

ROLLBACK;
