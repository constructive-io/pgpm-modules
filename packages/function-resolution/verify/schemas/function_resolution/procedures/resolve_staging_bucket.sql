-- Verify schemas/function_resolution/procedures/resolve_staging_bucket  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve_staging_bucket(uuid, text, uuid)'::regprocedure);

ROLLBACK;
