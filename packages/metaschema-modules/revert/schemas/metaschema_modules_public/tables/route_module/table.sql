-- Revert schemas/metaschema_modules_public/tables/route_module/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_modules_public.route_module;

COMMIT;
