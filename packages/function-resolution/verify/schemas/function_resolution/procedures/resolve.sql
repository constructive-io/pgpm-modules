-- Verify schemas/function_resolution/procedures/resolve  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve(uuid, text, uuid, text, bool)'::regprocedure);

ROLLBACK;
