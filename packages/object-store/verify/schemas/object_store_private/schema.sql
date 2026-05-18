-- Verify schemas/object_store_private/schema  on pg

BEGIN;

SELECT verify_schema ('object_store_private');

ROLLBACK;
