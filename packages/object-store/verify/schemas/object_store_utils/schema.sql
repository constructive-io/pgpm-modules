-- Verify schemas/object_store_utils/schema  on pg

BEGIN;

SELECT verify_schema ('object_store_utils');

ROLLBACK;
