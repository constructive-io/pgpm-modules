-- Verify schemas/encrypted_secrets/procedures/secrets_getter  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.secrets_getter(uuid, text, text)'::regprocedure);

ROLLBACK;
