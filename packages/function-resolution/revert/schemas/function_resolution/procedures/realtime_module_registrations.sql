-- Revert schemas/function_resolution/procedures/realtime_module_registrations from pg

BEGIN;
DROP FUNCTION function_resolution.realtime_module_registrations(uuid);
COMMIT;
