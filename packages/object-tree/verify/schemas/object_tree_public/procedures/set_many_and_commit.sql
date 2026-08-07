-- Verify schemas/object_tree_public/procedures/set_many_and_commit  on pg

BEGIN;

SELECT assert_function('object_tree_public.set_many_and_commit(uuid, uuid, text, jsonb)'::regprocedure);

ROLLBACK;
