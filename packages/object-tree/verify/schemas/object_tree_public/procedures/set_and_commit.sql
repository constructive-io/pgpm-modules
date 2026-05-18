-- Verify schemas/object_tree_public/procedures/set_and_commit  on pg

BEGIN;

SELECT verify_function ('object_tree_public.set_and_commit');

ROLLBACK;
