-- Verify schemas/app_scope/procedures/routing_tables  on pg

BEGIN;

SELECT verify_function ('app_scope.routing_tables');

ROLLBACK;
