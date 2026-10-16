-- Revert schemas/function_resolution/procedures/internal_config_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.internal_config_module_registrations(uuid);

COMMIT;
