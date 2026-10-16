-- Revert schemas/function_resolution/procedures/identity_providers_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.identity_providers_module_registrations(uuid);

COMMIT;
