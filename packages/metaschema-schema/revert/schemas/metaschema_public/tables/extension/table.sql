-- Revert schemas/metaschema_public/tables/extension/table from pg

BEGIN;

DROP TABLE metaschema_public.extension;

COMMIT;
