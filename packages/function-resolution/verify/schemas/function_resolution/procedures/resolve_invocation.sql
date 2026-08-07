-- Verify schemas/function_resolution/procedures/resolve_invocation  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve_invocation(uuid, text, uuid, text, uuid, text, uuid)'::regprocedure);

ROLLBACK;
