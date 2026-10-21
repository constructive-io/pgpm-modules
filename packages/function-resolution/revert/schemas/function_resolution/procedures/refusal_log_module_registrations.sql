-- Revert schemas/function_resolution/procedures/refusal_log_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.refusal_log_module_registrations(uuid);

COMMIT;
