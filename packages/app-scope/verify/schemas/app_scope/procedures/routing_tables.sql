-- Verify schemas/app_scope/procedures/routing_tables  on pg

BEGIN;

SELECT assert_function('app_scope.routing_tables(uuid, text)'::regprocedure);

ROLLBACK;
