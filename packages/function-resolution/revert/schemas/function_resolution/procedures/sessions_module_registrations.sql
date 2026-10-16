-- Revert schemas/function_resolution/procedures/sessions_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.sessions_module_registrations(uuid);

COMMIT;
