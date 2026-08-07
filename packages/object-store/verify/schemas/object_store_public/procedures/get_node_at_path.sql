-- Verify schemas/object_store_public/procedures/get_node_at_path  on pg

BEGIN;

SELECT assert_function('object_store_public.get_node_at_path(uuid, uuid, text[])'::regprocedure);

ROLLBACK;
