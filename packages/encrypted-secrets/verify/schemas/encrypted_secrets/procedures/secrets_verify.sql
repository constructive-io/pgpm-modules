-- Verify schemas/encrypted_secrets/procedures/secrets_verify  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.secrets_verify(uuid, text, text)'::regprocedure);

ROLLBACK;
