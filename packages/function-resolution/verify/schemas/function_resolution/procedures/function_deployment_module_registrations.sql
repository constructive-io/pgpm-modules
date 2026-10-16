-- Verify schemas/function_resolution/procedures/function_deployment_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.function_deployment_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
