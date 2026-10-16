-- Revert schemas/function_resolution/procedures/site_surface_module_registrations from pg

BEGIN;

DROP FUNCTION function_resolution.site_surface_module_registrations(uuid);

COMMIT;
