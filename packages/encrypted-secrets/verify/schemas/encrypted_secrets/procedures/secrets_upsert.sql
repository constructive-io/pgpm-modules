-- Verify schemas/encrypted_secrets/procedures/secrets_upsert  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.secrets_upsert(uuid, text, text, text)'::regprocedure);

ROLLBACK;
