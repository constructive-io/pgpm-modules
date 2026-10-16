-- Revert schemas/function_resolution/procedures/notifications_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.notifications_module_registrations(uuid);

COMMIT;
