-- Revert schemas/object_store_public/procedures/get_node_at_path from pg

BEGIN;

DROP FUNCTION object_store_public.get_node_at_path;

COMMIT;
