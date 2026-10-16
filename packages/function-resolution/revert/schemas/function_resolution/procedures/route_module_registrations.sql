-- Revert schemas/function_resolution/procedures/route_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.route_module_registrations(uuid, text);

COMMIT;
