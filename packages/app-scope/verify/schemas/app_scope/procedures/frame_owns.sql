-- Verify schemas/app_scope/procedures/frame_owns  on pg

BEGIN;

SELECT assert_function('app_scope.frame_owns(uuid, text, uuid, text, uuid, uuid)'::regprocedure);

ROLLBACK;
