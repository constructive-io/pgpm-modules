-- Verify schemas/function_resolution/procedures/resolve_default_bucket  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve_default_bucket(text, uuid, boolean, text)'::regprocedure);

ROLLBACK;
