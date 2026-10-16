-- Verify schemas/function_resolution/procedures/user_auth_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.user_auth_module_registrations(uuid)'::regprocedure);

ROLLBACK;
