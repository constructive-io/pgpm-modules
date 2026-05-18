-- Revert schemas/object_tree_public/tables/store/table from pg

BEGIN;

DROP TABLE object_tree_public.store;

COMMIT;
