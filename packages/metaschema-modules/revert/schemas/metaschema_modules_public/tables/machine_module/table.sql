-- Revert schemas/metaschema_modules_public/tables/machine_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.machine_module;

COMMIT;
