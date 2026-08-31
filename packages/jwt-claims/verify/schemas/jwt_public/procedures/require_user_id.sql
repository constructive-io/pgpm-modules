-- Verify schemas/jwt_public/procedures/require_user_id on pg

BEGIN;

SELECT assert_function('jwt_public.require_user_id()'::regprocedure);

ROLLBACK;
