-- Verify schemas/encrypted_secrets/procedures/encrypt_field_set  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.encrypt_field_set(text)'::regprocedure);

ROLLBACK;
