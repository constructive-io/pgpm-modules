-- Verify schemas/jwt_public/procedures/current_role_type on pg

BEGIN;

SELECT assert_function('jwt_public.current_role_type()'::regprocedure);

ROLLBACK;
