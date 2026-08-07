-- Verify schemas/app_scope/procedures/frames  on pg

BEGIN;

SELECT assert_function('app_scope.frames(uuid, text, uuid)'::regprocedure);

ROLLBACK;
