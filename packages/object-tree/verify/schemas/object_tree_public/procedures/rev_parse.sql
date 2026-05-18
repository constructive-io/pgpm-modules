-- Verify schemas/object_tree_public/procedures/rev_parse  on pg

BEGIN;

SELECT verify_function ('object_tree_public.rev_parse');

ROLLBACK;
