-- Verify schemas/function_resolution/procedures/routing_planes  on pg

BEGIN;

SELECT assert_function('function_resolution.routing_planes()'::regprocedure);

ROLLBACK;
