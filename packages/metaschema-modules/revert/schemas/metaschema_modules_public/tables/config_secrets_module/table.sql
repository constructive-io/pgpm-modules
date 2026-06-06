-- Revert schemas/metaschema_modules_public/tables/config_secrets_module/table from pg

BEGIN;

DROP TABLE metaschema_modules_public.config_secrets_module;

COMMIT;
