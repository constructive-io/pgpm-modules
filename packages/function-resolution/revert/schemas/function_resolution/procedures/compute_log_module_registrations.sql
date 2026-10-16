-- Revert schemas/function_resolution/procedures/compute_log_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.compute_log_module_registrations(uuid);

COMMIT;
