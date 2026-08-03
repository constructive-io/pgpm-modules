-- Revert schemas/metaschema_public/tables/unique_constraint_behavior/table from pg

BEGIN;

DROP TABLE metaschema_public.unique_constraint_behavior;

COMMIT;
