-- Verify schemas/metaschema_modules_public/tables/capabilities_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.capabilities_module'::regclass);

ROLLBACK;
