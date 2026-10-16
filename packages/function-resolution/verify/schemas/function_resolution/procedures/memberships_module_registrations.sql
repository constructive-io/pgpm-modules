-- Verify schemas/function_resolution/procedures/memberships_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.memberships_module_registrations(uuid)'::regprocedure);

ROLLBACK;
