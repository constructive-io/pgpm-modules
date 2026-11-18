-- Verify schemas/function_resolution/procedures/auth_surface_entry  on pg

BEGIN;

SELECT assert_function('function_resolution.auth_surface_entry(uuid)'::regprocedure);

ROLLBACK;
