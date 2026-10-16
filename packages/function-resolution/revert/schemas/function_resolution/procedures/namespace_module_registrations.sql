-- Revert schemas/function_resolution/procedures/namespace_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.namespace_module_registrations(uuid, text);

COMMIT;
