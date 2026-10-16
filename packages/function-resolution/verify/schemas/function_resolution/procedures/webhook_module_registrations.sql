-- Verify schemas/function_resolution/procedures/webhook_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.webhook_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
