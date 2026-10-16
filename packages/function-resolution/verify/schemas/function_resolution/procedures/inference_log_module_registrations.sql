-- Verify schemas/function_resolution/procedures/inference_log_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.inference_log_module_registrations(uuid)'::regprocedure);

ROLLBACK;
