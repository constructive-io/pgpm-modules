-- Verify schemas/metaschema_modules_public/tables/notifications_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.notifications_module'::regclass);

ROLLBACK;
