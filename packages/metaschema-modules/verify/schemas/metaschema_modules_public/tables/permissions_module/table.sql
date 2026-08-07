-- Verify schemas/metaschema_modules_public/tables/permissions_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.permissions_module'::regclass);

ROLLBACK;
