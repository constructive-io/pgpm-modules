-- Verify schemas/function_resolution/procedures/transfer_log_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.transfer_log_module_registrations(uuid)'::regprocedure);

ROLLBACK;
