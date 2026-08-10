-- Revert schemas/metaschema_modules_public/tables/capabilities_module/table from pg

BEGIN;

DROP TABLE metaschema_modules_public.capabilities_module;

COMMIT;
