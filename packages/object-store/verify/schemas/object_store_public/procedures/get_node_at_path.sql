-- Verify schemas/object_store_public/procedures/get_node_at_path  on pg

BEGIN;

SELECT verify_function ('object_store_public.get_node_at_path');

ROLLBACK;
