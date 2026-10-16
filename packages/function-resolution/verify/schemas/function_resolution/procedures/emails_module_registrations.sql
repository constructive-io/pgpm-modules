-- Verify schemas/function_resolution/procedures/emails_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.emails_module_registrations(uuid)'::regprocedure);

ROLLBACK;
