-- Verify schemas/encrypted_secrets/schema  on pg

BEGIN;

SELECT assert_schema('encrypted_secrets'::regnamespace);

ROLLBACK;
