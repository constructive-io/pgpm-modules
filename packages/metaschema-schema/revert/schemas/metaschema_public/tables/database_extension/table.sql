-- Revert schemas/metaschema_public/tables/database_extension/table from pg

BEGIN;

DROP TABLE metaschema_public.database_extension;

COMMIT;
