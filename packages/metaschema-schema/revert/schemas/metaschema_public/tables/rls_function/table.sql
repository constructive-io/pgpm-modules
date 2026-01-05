-- Revert schemas/metaschema_public/tables/rls_function/table from pg

BEGIN;

DROP TABLE metaschema_public.rls_function;

COMMIT;
