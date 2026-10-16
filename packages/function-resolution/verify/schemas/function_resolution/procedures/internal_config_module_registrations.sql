-- Verify schemas/function_resolution/procedures/internal_config_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.internal_config_module_registrations(uuid)'::regprocedure);

ROLLBACK;
