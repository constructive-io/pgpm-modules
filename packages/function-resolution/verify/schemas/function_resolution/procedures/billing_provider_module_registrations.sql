-- Verify schemas/function_resolution/procedures/billing_provider_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.billing_provider_module_registrations(uuid)'::regprocedure);

ROLLBACK;
