-- Revert schemas/metaschema_modules_public/tables/organization_settings_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.organization_settings_module;

COMMIT;
