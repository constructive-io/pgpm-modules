-- Revert schemas/function_resolution/procedures/transfer_log_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.transfer_log_module_registrations(uuid);

COMMIT;
