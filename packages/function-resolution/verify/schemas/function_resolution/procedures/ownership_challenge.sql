-- Verify schemas/function_resolution/procedures/ownership_challenge  on pg

BEGIN;

SELECT assert_function('function_resolution.ownership_challenge(text, text)'::regprocedure);

ROLLBACK;
