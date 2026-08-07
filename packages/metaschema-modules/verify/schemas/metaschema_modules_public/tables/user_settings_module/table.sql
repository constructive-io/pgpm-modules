-- Verify schemas/metaschema_modules_public/tables/user_settings_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.user_settings_module'::regclass);

ROLLBACK;
