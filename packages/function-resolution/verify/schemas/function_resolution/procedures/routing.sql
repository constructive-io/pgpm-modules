-- Verify schemas/function_resolution/procedures/routing  on pg

BEGIN;

SELECT assert_function('function_resolution.routing(uuid, uuid)'::regprocedure);

ROLLBACK;
