-- Verify schemas/function_resolution/procedures/default_bucket_tag  on pg

BEGIN;

SELECT assert_function('function_resolution.default_bucket_tag(boolean)'::regprocedure);

ROLLBACK;
