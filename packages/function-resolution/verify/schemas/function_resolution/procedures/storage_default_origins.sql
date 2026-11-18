-- Verify schemas/function_resolution/procedures/storage_default_origins on pg

BEGIN;

SELECT assert_function('function_resolution.storage_default_origins(uuid)'::regprocedure);

ROLLBACK;
