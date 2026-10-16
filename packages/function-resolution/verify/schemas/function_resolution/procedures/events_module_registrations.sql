-- Verify schemas/function_resolution/procedures/events_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.events_module_registrations(uuid)'::regprocedure);

ROLLBACK;
