-- Verify schemas/function_resolution/procedures/resolve_default_bucket  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve_default_bucket(uuid, text, uuid, boolean, text)'::regprocedure);

ROLLBACK;
