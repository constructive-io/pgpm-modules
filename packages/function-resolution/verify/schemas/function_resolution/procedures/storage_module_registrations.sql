-- Verify schemas/function_resolution/procedures/storage_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.storage_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
