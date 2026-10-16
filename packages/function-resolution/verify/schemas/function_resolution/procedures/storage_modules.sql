-- Verify schemas/function_resolution/procedures/storage_modules  on pg

BEGIN;

SELECT assert_function('function_resolution.storage_modules()'::regprocedure);

ROLLBACK;
