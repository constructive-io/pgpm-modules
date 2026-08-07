-- Verify schemas/object_store_public/procedures/insert_nodes_at_paths  on pg

BEGIN;

SELECT assert_function('object_store_public.insert_nodes_at_paths(uuid, uuid, jsonb, jsonb[], jsonb, jsonb)'::regprocedure);

ROLLBACK;
