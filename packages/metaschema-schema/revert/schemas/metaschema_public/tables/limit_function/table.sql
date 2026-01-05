-- Revert schemas/metaschema_public/tables/limit_function/table from pg

BEGIN;

DROP TABLE metaschema_public.limit_function;

COMMIT;
