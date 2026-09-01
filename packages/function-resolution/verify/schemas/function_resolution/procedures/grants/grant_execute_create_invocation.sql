-- Verify schemas/function_resolution/procedures/grants/grant_execute_create_invocation on pg

BEGIN;

SELECT assert_function_grant('function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid)'::regprocedure, 'authenticated', 'EXECUTE');
SELECT assert_function_grant('function_resolution.create_invocation(uuid, text, text, jsonb, text, jsonb, uuid, uuid)'::regprocedure, 'anonymous', 'EXECUTE');

ROLLBACK;
