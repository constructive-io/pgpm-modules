-- Revert schemas/secrets_schema/tables/secrets_table/triggers/hash_secrets from pg

BEGIN;

DROP TRIGGER hash_secrets ON secrets_schema.secrets_table;
DROP FUNCTION secrets_schema.tg_hash_secrets; 

COMMIT;
