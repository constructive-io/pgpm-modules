-- Verify schemas/function_resolution/procedures/api_hostnames on pg

BEGIN;

SELECT assert_function('function_resolution.api_hostnames(uuid)'::regprocedure);

ROLLBACK;
