-- Verify schemas/jwt_public/procedures/current_principal_id on pg

BEGIN;

SELECT assert_function('jwt_public.current_principal_id()'::regprocedure);

ROLLBACK;
