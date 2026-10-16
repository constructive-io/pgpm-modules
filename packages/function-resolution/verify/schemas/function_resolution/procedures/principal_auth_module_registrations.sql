-- Verify schemas/function_resolution/procedures/principal_auth_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.principal_auth_module_registrations(uuid)'::regprocedure);

ROLLBACK;
