-- Revert schemas/function_resolution/procedures/storage_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.storage_module_registrations(uuid, text);

COMMIT;
