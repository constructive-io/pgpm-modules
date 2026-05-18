-- Revert schemas/object_tree_public/tables/ref/indexes/idx_unique_object_ref_name from pg

BEGIN;

DROP INDEX object_tree_public.idx_unique_object_ref_name;

COMMIT;
