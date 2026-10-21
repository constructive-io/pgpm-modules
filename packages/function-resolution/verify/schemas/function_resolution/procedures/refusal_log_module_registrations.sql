-- Verify schemas/function_resolution/procedures/refusal_log_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.refusal_log_module_registrations(uuid)'::regprocedure);

ROLLBACK;
