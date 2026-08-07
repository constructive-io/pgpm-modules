-- Verify schemas/metaschema_modules_public/tables/users_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.users_module'::regclass);

ROLLBACK;
