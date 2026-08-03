-- Revert schemas/metaschema_public/tables/field_behavior/table from pg

BEGIN;

DROP TABLE metaschema_public.field_behavior;

COMMIT;
