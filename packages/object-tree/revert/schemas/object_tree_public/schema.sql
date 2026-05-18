-- Revert schemas/object_tree_public/schema from pg

BEGIN;

DROP SCHEMA object_tree_public;

COMMIT;
