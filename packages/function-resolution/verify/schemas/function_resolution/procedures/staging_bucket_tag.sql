-- Verify schemas/function_resolution/procedures/staging_bucket_tag  on pg

BEGIN;

SELECT assert_function('function_resolution.staging_bucket_tag()'::regprocedure);

ROLLBACK;
