-- Verify schemas/function_resolution/procedures/route_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.route_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
