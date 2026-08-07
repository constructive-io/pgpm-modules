-- Revert schemas/object_store_public/procedures/insert_node_at_path from pg

BEGIN;

DROP FUNCTION object_store_public.insert_node_at_path(uuid, uuid, text[], jsonb, uuid[], text[]);

COMMIT;
