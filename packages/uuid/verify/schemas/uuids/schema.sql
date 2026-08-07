-- Verify schemas/uuids/schema  on pg

BEGIN;

SELECT assert_schema('uuids'::regnamespace);

ROLLBACK;
