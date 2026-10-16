-- Revert schemas/function_resolution/procedures/webauthn_entry from pg

BEGIN;

DROP FUNCTION function_resolution.webauthn_entry(uuid);

COMMIT;
