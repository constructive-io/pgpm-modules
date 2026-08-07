-- Verify schemas/metaschema_modules_public/tables/devices_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.devices_module'::regclass);

ROLLBACK;
