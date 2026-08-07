-- Revert schemas/encrypted_secrets/procedures/secrets_upsert from pg

BEGIN;

DROP FUNCTION encrypted_secrets.secrets_upsert(uuid, text, text, text);

COMMIT;
