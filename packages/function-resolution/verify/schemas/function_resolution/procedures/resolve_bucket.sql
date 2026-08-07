-- Verify schemas/function_resolution/procedures/resolve_bucket  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve_bucket(uuid, text, uuid, text[], text)'::regprocedure);

ROLLBACK;
