-- Revert schemas/object_tree_private/schema from pg

BEGIN;

DROP SCHEMA object_tree_private;

COMMIT;
