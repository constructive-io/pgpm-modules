-- Verify schemas/object_tree_public/procedures/get_object_at_path  on pg

BEGIN;

SELECT verify_function ('object_tree_public.get_object_at_path');

ROLLBACK;
