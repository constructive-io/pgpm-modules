-- Verify schemas/object_store_private/schema  on pg

BEGIN;

SELECT assert_schema('object_store_private'::regnamespace);

ROLLBACK;
