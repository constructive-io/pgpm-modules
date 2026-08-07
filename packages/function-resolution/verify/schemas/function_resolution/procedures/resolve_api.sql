-- Verify schemas/function_resolution/procedures/resolve_api  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve_api(uuid, text, uuid, text)'::regprocedure);

ROLLBACK;
