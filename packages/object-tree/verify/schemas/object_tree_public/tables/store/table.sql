-- Verify schemas/object_tree_public/tables/store/table on pg

BEGIN;

SELECT verify_table ('object_tree_public.store');

ROLLBACK;
