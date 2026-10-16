-- Verify schemas/function_resolution/procedures/database_standing  on pg

BEGIN;

SELECT assert_function('function_resolution.database_standing(uuid)'::regprocedure);

ROLLBACK;
