-- Verify schemas/function_resolution/procedures/phone_numbers_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.phone_numbers_module_registrations(uuid)'::regprocedure);

ROLLBACK;
