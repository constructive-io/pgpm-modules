-- Verify schemas/encrypted_secrets/procedures/encrypt_field_pgp_getter  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.encrypt_field_pgp_getter(uuid, text, text)'::regprocedure);

ROLLBACK;
