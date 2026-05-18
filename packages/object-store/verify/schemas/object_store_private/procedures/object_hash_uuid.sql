-- Verify schemas/object_store_private/procedures/object_hash_uuid  on pg

BEGIN;

SELECT verify_function ('object_store_public.object_hash_uuid');

ROLLBACK;
