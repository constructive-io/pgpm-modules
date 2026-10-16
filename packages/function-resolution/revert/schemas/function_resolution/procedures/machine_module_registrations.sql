-- Revert schemas/function_resolution/procedures/machine_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.machine_module_registrations(uuid, text);

COMMIT;
