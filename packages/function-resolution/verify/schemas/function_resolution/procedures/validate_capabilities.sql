-- Verify schemas/function_resolution/procedures/validate_capabilities  on pg

BEGIN;

SELECT assert_function('function_resolution.validate_capabilities(uuid, text, uuid, uuid, text, uuid, jsonb, text)'::regprocedure);

ROLLBACK;
