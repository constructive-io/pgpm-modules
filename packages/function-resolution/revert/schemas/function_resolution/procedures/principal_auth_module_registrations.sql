-- Revert schemas/function_resolution/procedures/principal_auth_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.principal_auth_module_registrations(uuid);

COMMIT;
