-- Revert schemas/object_tree_public/tables/commit/table from pg

BEGIN;

DROP TABLE object_tree_public.commit;

COMMIT;
