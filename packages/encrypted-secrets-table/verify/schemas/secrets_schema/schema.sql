-- Verify schemas/secrets_schema/schema  on pg

BEGIN;

SELECT assert_schema('secrets_schema'::regnamespace);

ROLLBACK;
