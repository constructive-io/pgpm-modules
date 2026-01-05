-- Revert schemas/metaschema_modules_public/tables/tokens_module/table from pg

BEGIN;

DROP TABLE metaschema_modules_public.tokens_module;

COMMIT;
