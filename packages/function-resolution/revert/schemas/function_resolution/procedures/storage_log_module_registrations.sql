-- Revert schemas/function_resolution/procedures/storage_log_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.storage_log_module_registrations(uuid);

COMMIT;
