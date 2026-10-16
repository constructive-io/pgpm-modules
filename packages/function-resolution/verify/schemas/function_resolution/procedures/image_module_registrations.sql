-- Verify schemas/function_resolution/procedures/image_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.image_module_registrations(uuid, text)'::regprocedure);

ROLLBACK;
