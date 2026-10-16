-- Verify schemas/function_resolution/procedures/resource_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.resource_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
