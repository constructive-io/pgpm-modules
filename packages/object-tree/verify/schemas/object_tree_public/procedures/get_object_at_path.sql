-- Verify schemas/object_tree_public/procedures/get_object_at_path  on pg

BEGIN;

SELECT assert_function('object_tree_public.get_object_at_path(uuid, uuid, text[], text)'::regprocedure);

ROLLBACK;
