-- Verify schemas/function_resolution/procedures/email_sender_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.email_sender_module_registrations(uuid)'::regprocedure);

ROLLBACK;
