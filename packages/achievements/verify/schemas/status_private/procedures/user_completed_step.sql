-- Verify schemas/status_private/procedures/user_completed_step  on pg

BEGIN;

SELECT assert_function('status_private.user_completed_step(text, uuid)'::regprocedure);

ROLLBACK;
