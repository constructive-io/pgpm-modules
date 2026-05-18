-- Revert schemas/object_store_private/procedures/object_hash_uuid from pg

BEGIN;

DROP FUNCTION object_store_public.object_hash_uuid;

COMMIT;
