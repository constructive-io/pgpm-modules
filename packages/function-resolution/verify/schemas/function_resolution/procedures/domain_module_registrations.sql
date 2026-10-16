-- Verify schemas/function_resolution/procedures/domain_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.domain_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
