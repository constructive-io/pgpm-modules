-- Verify schemas/encrypted_secrets/procedures/secrets_table_upsert  on pg

BEGIN;

SELECT assert_function('encrypted_secrets.secrets_table_upsert(uuid, json)'::regprocedure);

ROLLBACK;
