-- Verify schemas/encrypted_secrets/procedures/secrets_delete  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.secrets_delete(uuid, text)'::regprocedure);
SELECT assert_function('encrypted_secrets.secrets_delete(uuid, text[])'::regprocedure);

ROLLBACK;
