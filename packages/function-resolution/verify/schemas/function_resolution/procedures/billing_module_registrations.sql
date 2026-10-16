-- Verify schemas/function_resolution/procedures/billing_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.billing_module_registrations(uuid)'::regprocedure);

ROLLBACK;
