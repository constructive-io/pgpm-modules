-- Verify schemas/object_tree_public/tables/ref/table on pg

BEGIN;

SELECT assert_table('object_tree_public.ref'::regclass);

ROLLBACK;
