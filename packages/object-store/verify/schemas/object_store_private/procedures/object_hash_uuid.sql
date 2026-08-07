-- Verify schemas/object_store_private/procedures/object_hash_uuid  on pg

BEGIN;

SELECT assert_function('object_store_public.object_hash_uuid(object_store_public.object)'::regprocedure);

ROLLBACK;
