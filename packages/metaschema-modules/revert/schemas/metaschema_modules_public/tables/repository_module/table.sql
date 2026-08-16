-- Revert schemas/metaschema_modules_public/tables/repository_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.repository_module;

COMMIT;
