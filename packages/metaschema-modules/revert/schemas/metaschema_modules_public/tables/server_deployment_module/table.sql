-- Revert schemas/metaschema_modules_public/tables/server_deployment_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.server_deployment_module;

COMMIT;
