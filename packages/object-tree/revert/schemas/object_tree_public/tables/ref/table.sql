-- Revert schemas/object_tree_public/tables/ref/table from pg

BEGIN;

DROP TABLE object_tree_public.ref;

COMMIT;
