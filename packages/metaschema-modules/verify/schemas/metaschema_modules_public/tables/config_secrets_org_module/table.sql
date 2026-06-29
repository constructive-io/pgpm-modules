-- Verify schemas/metaschema_modules_public/tables/config_secrets_org_module/table on pg

SELECT id, database_id
FROM metaschema_modules_public.config_secrets_org_module
WHERE FALSE;
