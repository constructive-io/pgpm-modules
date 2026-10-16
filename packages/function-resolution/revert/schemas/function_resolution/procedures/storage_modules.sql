-- Revert schemas/function_resolution/procedures/storage_modules from pg

BEGIN;

DROP FUNCTION function_resolution.storage_modules();

COMMIT;
