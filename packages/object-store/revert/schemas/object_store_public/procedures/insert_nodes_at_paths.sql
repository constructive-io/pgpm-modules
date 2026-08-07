-- Revert schemas/object_store_public/procedures/insert_nodes_at_paths from pg

BEGIN;

DROP FUNCTION object_store_public.insert_nodes_at_paths(uuid, uuid, jsonb, jsonb[], jsonb, jsonb);

COMMIT;
