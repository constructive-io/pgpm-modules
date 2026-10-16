-- Verify schemas/function_resolution/procedures/db_usage_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.db_usage_module_registrations(uuid)'::regprocedure);

ROLLBACK;
