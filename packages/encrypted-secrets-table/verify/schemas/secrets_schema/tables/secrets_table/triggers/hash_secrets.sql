-- Verify schemas/secrets_schema/tables/secrets_table/triggers/hash_secrets  on pg

BEGIN;

SELECT assert_function('secrets_schema.tg_hash_secrets()'::regprocedure);
SELECT assert_trigger('secrets_schema.secrets_table'::regclass, 'hash_secrets_update', 'secrets_schema.tg_hash_secrets'::regproc, 19);
SELECT assert_trigger('secrets_schema.secrets_table'::regclass, 'hash_secrets_insert', 'secrets_schema.tg_hash_secrets'::regproc, 7);

ROLLBACK;
