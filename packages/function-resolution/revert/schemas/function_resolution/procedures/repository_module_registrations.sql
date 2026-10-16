-- Revert schemas/function_resolution/procedures/repository_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.repository_module_registrations(uuid, text);

COMMIT;
