-- Verify schemas/function_resolution/procedures/api_by_name on pg

BEGIN;

SELECT assert_function('function_resolution.api_by_name(uuid, text)'::regprocedure);

ROLLBACK;
