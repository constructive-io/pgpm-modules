-- Revert schemas/metaschema_modules_public/tables/server_definition_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.server_definition_module;

COMMIT;
