-- Verify schemas/function_resolution/procedures/identity_providers_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.identity_providers_module_registrations(uuid)'::regprocedure);

ROLLBACK;
