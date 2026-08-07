-- Verify schemas/object_store_private/procedures/node_hash_uuid  on pg

BEGIN;

SELECT assert_function('object_store_private.node_hash_uuid(jsonb, uuid[], text[])'::regprocedure);

ROLLBACK;
