-- Revert schemas/function_resolution/procedures/storage_default_origins from pg

BEGIN;

DROP FUNCTION function_resolution.storage_default_origins(uuid);

COMMIT;
