-- Verify schemas/function_resolution/procedures/sessions_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.sessions_module_registrations(uuid)'::regprocedure);

ROLLBACK;
