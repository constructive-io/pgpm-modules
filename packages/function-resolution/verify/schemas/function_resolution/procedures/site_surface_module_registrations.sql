-- Verify schemas/function_resolution/procedures/site_surface_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.site_surface_module_registrations(uuid)'::regprocedure);

ROLLBACK;
