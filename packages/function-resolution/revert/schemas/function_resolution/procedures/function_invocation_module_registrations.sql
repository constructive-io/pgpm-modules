-- Revert schemas/function_resolution/procedures/function_invocation_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.function_invocation_module_registrations(uuid, text);

COMMIT;
