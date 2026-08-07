-- Revert schemas/metaschema_modules_public/tables/scope_types_module/table from pg

BEGIN;

DROP TABLE metaschema_modules_public.scope_types_module;

COMMIT;
