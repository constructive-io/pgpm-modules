-- Verify schemas/function_resolution/procedures/bound_bucket_id  on pg

BEGIN;

SELECT assert_function('function_resolution.bound_bucket_id(uuid, text, uuid, uuid, text)'::regprocedure);

ROLLBACK;
