-- Verify schemas/encrypted_secrets/procedures/encrypt_field_pgp_get  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.encrypt_field_pgp_get(bytea, text)'::regprocedure);

ROLLBACK;
