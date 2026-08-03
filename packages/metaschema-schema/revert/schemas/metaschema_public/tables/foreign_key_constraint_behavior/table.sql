-- Revert schemas/metaschema_public/tables/foreign_key_constraint_behavior/table from pg

BEGIN;

DROP TABLE metaschema_public.foreign_key_constraint_behavior;

COMMIT;
