-- Revert schemas/metaschema_modules_public/tables/image_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.image_module;

COMMIT;
