-- Revert schemas/object_store_public/procedures/update_node_at_path from pg

BEGIN;

DROP FUNCTION object_store_public.update_node_at_path;

COMMIT;
