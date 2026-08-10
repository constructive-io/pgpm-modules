-- Revert schemas/metaschema_modules_public/tables/content_preset_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.content_preset_module CASCADE;

COMMIT;
