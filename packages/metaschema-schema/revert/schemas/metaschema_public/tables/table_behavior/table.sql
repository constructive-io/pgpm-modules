-- Revert schemas/metaschema_public/tables/table_behavior/table from pg

BEGIN;

DROP TABLE metaschema_public.table_behavior;

COMMIT;
