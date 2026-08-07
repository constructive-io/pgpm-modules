-- Verify schemas/encrypted_secrets/procedures/encrypt_field_pgp  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.encrypt_field_pgp()'::regprocedure);

ROLLBACK;
