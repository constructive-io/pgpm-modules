-- Verify schemas/object_store_public/procedures/insert_node_at_path  on pg

BEGIN;

SELECT verify_function ('object_store_public.insert_node_at_path');

ROLLBACK;
