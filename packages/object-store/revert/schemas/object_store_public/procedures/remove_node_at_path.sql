-- Revert schemas/object_store_public/procedures/remove_node_at_path from pg

BEGIN;

DROP FUNCTION object_store_public.remove_node_at_path;

COMMIT;
