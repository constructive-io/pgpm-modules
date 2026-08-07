-- Verify schemas/metaschema_modules_public/tables/connected_accounts_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.connected_accounts_module'::regclass);

ROLLBACK;
