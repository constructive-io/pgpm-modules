-- Verify schemas/function_resolution/procedures/pages_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.pages_module_registrations(uuid)'::regprocedure);

ROLLBACK;
