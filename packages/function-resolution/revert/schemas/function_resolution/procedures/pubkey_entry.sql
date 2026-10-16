-- Revert schemas/function_resolution/procedures/pubkey_entry from pg

BEGIN;

DROP FUNCTION function_resolution.pubkey_entry(uuid);

COMMIT;
