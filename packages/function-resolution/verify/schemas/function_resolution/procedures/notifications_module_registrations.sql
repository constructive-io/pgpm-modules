-- Verify schemas/function_resolution/procedures/notifications_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.notifications_module_registrations(uuid)'::regprocedure);

ROLLBACK;
