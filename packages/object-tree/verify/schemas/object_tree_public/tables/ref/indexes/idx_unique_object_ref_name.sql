-- Verify schemas/object_tree_public/tables/ref/indexes/idx_unique_object_ref_name on pg

BEGIN;

SELECT verify_index ('object_tree_public.ref', 'idx_unique_object_ref_name');

ROLLBACK;
