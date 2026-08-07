-- Verify schemas/object_tree_public/tables/ref/indexes/idx_unique_object_ref_name on pg

BEGIN;

SELECT assert_index('object_tree_public.idx_unique_object_ref_name'::regclass, 'object_tree_public.ref'::regclass, true);

ROLLBACK;
