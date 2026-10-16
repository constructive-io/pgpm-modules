-- Verify schemas/function_resolution/procedures/namespace_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.namespace_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
