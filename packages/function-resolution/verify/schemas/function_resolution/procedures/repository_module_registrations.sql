-- Verify schemas/function_resolution/procedures/repository_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.repository_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
