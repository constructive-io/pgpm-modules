-- Verify schemas/function_resolution/procedures/is_platform_default_storage_module on pg

BEGIN;

SELECT assert_function('function_resolution.is_platform_default_storage_module(uuid)'::regprocedure);

ROLLBACK;
