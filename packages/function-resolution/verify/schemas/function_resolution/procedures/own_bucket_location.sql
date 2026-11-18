-- Verify schemas/function_resolution/procedures/own_bucket_location  on pg

BEGIN;

SELECT assert_function('function_resolution.own_bucket_location(uuid)'::regprocedure);

ROLLBACK;
