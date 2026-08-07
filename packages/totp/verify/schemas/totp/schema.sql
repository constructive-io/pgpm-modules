-- Verify schemas/totp/schema  on pg

BEGIN;

SELECT assert_schema('totp'::regnamespace);

ROLLBACK;
