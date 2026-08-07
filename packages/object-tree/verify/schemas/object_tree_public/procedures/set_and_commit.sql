-- Verify schemas/object_tree_public/procedures/set_and_commit  on pg

BEGIN;

SELECT assert_function('object_tree_public.set_and_commit(uuid, uuid, text, text[], jsonb, uuid[], text[], text)'::regprocedure);

ROLLBACK;
