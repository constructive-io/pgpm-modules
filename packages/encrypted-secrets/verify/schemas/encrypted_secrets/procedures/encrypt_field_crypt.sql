-- Verify schemas/encrypted_secrets/procedures/encrypt_field_crypt  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.encrypt_field_crypt()'::regprocedure);

ROLLBACK;
