-- Verify schemas/jwt_public/procedures/current_user_id  on pg

BEGIN;

SELECT assert_function('jwt_public.current_user_id()'::regprocedure);

ROLLBACK;
