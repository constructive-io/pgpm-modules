-- Revert schemas/function_resolution/procedures/events_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.events_module_registrations(uuid);

COMMIT;
