-- Verify schemas/metaschema_modules_public/tables/config_secrets_org_module/table on pg

BEGIN;

SELECT verify_table ('metaschema_modules_public.config_secrets_org_module');

ROLLBACK;
