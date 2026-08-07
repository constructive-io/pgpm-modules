-- Verify schemas/base32/schema  on pg

BEGIN;

SELECT assert_schema('base32'::regnamespace);

ROLLBACK;
