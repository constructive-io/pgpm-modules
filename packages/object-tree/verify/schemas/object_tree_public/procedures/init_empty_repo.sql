-- Verify schemas/object_tree_public/procedures/init_empty_repo  on pg

BEGIN;

SELECT assert_function('object_tree_public.init_empty_repo(uuid, uuid)'::regprocedure);

ROLLBACK;
