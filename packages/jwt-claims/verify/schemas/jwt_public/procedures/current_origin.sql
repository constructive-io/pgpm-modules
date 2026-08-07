-- Verify schemas/jwt_public/procedures/current_origin  on pg

BEGIN;

SELECT assert_function('jwt_public.current_origin()'::regprocedure);

ROLLBACK;

