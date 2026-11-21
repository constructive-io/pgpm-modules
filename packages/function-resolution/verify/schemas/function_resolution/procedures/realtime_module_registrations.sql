-- Verify schemas/function_resolution/procedures/realtime_module_registrations on pg

BEGIN;
SELECT assert_function('function_resolution.realtime_module_registrations(uuid)'::regprocedure);
ROLLBACK;
