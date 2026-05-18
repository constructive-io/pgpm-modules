-- Verify schemas/object_store_public/schema  on pg

BEGIN;

SELECT verify_schema ('object_store_public');

ROLLBACK;
