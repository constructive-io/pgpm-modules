-- Verify schemas/metaschema_modules_public/tables/crypto_auth_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.crypto_auth_module'::regclass);

ROLLBACK;
