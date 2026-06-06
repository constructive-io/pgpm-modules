-- Verify schemas/metaschema_modules_public/tables/session_secrets_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.session_secrets_module');

ROLLBACK;
