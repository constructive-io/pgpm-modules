-- Revert schemas/function_resolution/procedures/memberships_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.memberships_module_registrations(uuid);

COMMIT;
