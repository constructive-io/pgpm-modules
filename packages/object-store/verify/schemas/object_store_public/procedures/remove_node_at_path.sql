-- Verify schemas/object_store_public/procedures/remove_node_at_path  on pg

BEGIN;

SELECT assert_function('object_store_public.remove_node_at_path(uuid, uuid, text[])'::regprocedure);

ROLLBACK;
