-- Verify schemas/object_tree_public/tables/commit/table on pg

BEGIN;

SELECT verify_table ('object_tree_public.commit');

ROLLBACK;
