-- Revert schemas/function_resolution/procedures/plans_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.plans_module_registrations(uuid);

COMMIT;
