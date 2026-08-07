-- Verify schemas/object_tree_public/tables/store/table on pg

BEGIN;

SELECT assert_table('object_tree_public.store'::regclass);

ROLLBACK;
