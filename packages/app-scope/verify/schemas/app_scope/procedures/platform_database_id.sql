-- Verify schemas/app_scope/procedures/platform_database_id  on pg

BEGIN;

SELECT assert_function('app_scope.platform_database_id()'::regprocedure);

ROLLBACK;
