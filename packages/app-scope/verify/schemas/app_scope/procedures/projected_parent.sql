-- Verify schemas/app_scope/procedures/projected_parent  on pg

BEGIN;

SELECT assert_function('app_scope.projected_parent(uuid, text)'::regprocedure);

ROLLBACK;
