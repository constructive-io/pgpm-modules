-- Revert schemas/function_resolution/procedures/resource_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.resource_module_registrations(uuid, text);

COMMIT;
