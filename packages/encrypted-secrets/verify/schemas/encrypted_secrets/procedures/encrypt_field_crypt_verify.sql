-- Verify schemas/encrypted_secrets/procedures/encrypt_field_crypt_verify  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.encrypt_field_crypt_verify(uuid, text, text)'::regprocedure);

ROLLBACK;
