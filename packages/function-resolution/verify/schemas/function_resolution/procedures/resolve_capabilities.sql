-- Verify schemas/function_resolution/procedures/resolve_capabilities  on pg

BEGIN;

SELECT assert_function('function_resolution.resolve_capabilities(uuid, text, uuid, uuid, text, uuid, jsonb, text)'::regprocedure);

ROLLBACK;
