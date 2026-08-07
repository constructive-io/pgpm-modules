-- Verify schemas/object_store_public/schema  on pg

BEGIN;

SELECT assert_schema('object_store_public'::regnamespace);

ROLLBACK;
