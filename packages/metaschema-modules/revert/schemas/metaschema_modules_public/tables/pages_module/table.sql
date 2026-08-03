-- Revert schemas/metaschema_modules_public/tables/pages_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.pages_module CASCADE;

COMMIT;
