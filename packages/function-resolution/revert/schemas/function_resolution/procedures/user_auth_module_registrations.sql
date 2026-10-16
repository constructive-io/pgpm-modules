-- Revert schemas/function_resolution/procedures/user_auth_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.user_auth_module_registrations(uuid);

COMMIT;
