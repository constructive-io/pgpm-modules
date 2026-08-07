-- Verify schemas/app_scope/procedures/membership_parent  on pg

BEGIN;

SELECT assert_function('app_scope.membership_parent(uuid, text)'::regprocedure);

ROLLBACK;
