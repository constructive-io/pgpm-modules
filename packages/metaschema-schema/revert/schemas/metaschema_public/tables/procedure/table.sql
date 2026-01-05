-- Revert schemas/metaschema_public/tables/procedure/table from pg

BEGIN;

DROP TABLE metaschema_public.procedure;

COMMIT;
