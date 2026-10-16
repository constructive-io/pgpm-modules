-- Revert schemas/function_resolution/procedures/pages_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.pages_module_registrations(uuid);

COMMIT;
