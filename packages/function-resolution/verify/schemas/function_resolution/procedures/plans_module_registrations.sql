-- Verify schemas/function_resolution/procedures/plans_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.plans_module_registrations(uuid)'::regprocedure);

ROLLBACK;
