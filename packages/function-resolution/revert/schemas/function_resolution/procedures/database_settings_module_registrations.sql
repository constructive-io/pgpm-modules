-- Revert schemas/function_resolution/procedures/database_settings_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.database_settings_module_registrations(uuid);

COMMIT;
