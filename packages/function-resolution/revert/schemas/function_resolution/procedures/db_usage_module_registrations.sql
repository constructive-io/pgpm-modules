-- Revert schemas/function_resolution/procedures/db_usage_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.db_usage_module_registrations(uuid);

COMMIT;
