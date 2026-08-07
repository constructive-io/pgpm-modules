-- Verify schemas/object_tree_public/tables/commit/table on pg

BEGIN;

SELECT assert_table('object_tree_public.commit'::regclass);

ROLLBACK;
