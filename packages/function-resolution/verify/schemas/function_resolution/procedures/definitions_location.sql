-- Verify schemas/function_resolution/procedures/definitions_location  on pg

BEGIN;

SELECT assert_function('function_resolution.definitions_location(uuid, text)'::regprocedure);

ROLLBACK;
