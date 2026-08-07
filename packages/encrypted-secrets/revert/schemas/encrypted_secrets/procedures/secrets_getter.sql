-- Revert schemas/encrypted_secrets/procedures/secrets_getter from pg

BEGIN;

DROP FUNCTION encrypted_secrets.secrets_getter(uuid, text, text);

COMMIT;
