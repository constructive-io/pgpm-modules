-- Verify schemas/object_store_public/procedures/update_node_at_path  on pg

BEGIN;

SELECT verify_function ('object_store_public.update_node_at_path');

ROLLBACK;
