-- Verify schemas/app_scope/procedures/local_frames  on pg

BEGIN;

SELECT assert_function('app_scope.local_frames(uuid, text, uuid)'::regprocedure);

ROLLBACK;
