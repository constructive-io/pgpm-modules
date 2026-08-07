-- Verify schemas/metaschema_modules_public/tables/storage_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.storage_module'::regclass);

ROLLBACK;
