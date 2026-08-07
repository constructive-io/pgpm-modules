-- Verify schemas/object_tree_public/procedures/rev_parse  on pg

BEGIN;

SELECT assert_function('object_tree_public.rev_parse(uuid, uuid, text)'::regprocedure);

ROLLBACK;
