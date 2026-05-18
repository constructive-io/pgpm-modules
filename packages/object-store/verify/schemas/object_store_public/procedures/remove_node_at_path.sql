-- Verify schemas/object_store_public/procedures/remove_node_at_path  on pg

BEGIN;

SELECT verify_function ('object_store_public.remove_node_at_path');

ROLLBACK;
