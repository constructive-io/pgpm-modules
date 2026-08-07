-- Verify schemas/metaschema_modules_public/tables/default_ids_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.default_ids_module'::regclass);

ROLLBACK;
