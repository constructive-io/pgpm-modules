-- Verify schemas/object_store_utils/schema  on pg

BEGIN;

SELECT assert_schema('object_store_utils'::regnamespace);

ROLLBACK;
