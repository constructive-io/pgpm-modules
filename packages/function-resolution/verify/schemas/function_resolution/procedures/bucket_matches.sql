-- Verify schemas/function_resolution/procedures/bucket_matches  on pg

BEGIN;

SELECT assert_function('function_resolution.bucket_matches(uuid, text, uuid, text[], text)'::regprocedure);

ROLLBACK;
