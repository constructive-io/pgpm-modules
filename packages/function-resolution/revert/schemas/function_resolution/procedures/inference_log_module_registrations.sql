-- Revert schemas/function_resolution/procedures/inference_log_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.inference_log_module_registrations(uuid);

COMMIT;
