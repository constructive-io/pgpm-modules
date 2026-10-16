-- Verify schemas/function_resolution/procedures/machine_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.machine_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
