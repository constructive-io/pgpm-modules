-- Revert schemas/object_store_private/procedures/node_hash_uuid from pg

BEGIN;

DROP FUNCTION object_store_private.node_hash_uuid(jsonb, uuid[], text[]);

COMMIT;
