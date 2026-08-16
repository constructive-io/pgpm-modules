-- Revert schemas/metaschema_modules_public/tables/internal_config_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.internal_config_module CASCADE;

COMMIT;
