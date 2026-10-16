-- Verify schemas/function_resolution/procedures/storage_log_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.storage_log_module_registrations(uuid)'::regprocedure);

ROLLBACK;
