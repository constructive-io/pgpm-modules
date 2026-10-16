-- Verify schemas/function_resolution/procedures/database_settings_module_registrations  on pg

BEGIN;

SELECT assert_function('function_resolution.database_settings_module_registrations(uuid)'::regprocedure);

ROLLBACK;
