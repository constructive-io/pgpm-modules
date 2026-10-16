-- Verify schemas/function_resolution/procedures/cors_origins  on pg

BEGIN;

SELECT assert_function('function_resolution.cors_origins(uuid, uuid)'::regprocedure);

ROLLBACK;
