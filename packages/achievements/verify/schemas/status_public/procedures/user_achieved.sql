-- Verify schemas/status_public/procedures/user_achieved  on pg

BEGIN;

SELECT assert_function('status_public.user_achieved(text, uuid)'::regprocedure);

ROLLBACK;
