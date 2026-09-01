-- Verify schemas/function_resolution/procedures/create_invocation  on pg

BEGIN;

SELECT assert_function('function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid)'::regprocedure);

ROLLBACK;
