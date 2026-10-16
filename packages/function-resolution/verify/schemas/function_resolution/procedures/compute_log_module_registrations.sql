-- Verify schemas/function_resolution/procedures/compute_log_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.compute_log_module_registrations(uuid)'::regprocedure);

ROLLBACK;
