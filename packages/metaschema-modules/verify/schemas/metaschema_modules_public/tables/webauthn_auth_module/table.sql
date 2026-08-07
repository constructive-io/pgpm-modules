-- Verify schemas/metaschema_modules_public/tables/webauthn_auth_module/table on pg

BEGIN;

SELECT assert_table('metaschema_modules_public.webauthn_auth_module'::regclass);

ROLLBACK;
