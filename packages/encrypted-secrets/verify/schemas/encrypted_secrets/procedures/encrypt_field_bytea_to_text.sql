-- Verify schemas/encrypted_secrets/procedures/encrypt_field_bytea_to_text  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.encrypt_field_bytea_to_text(bytea)'::regprocedure);

ROLLBACK;
