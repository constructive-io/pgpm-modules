-- Verify schemas/status_private/procedures/user_incompleted_step  on pg

BEGIN;

SELECT assert_function('status_private.user_incompleted_step(text, uuid)'::regprocedure);

ROLLBACK;
