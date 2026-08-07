-- Verify schemas/jwt_public/procedures/current_ip_address  on pg

BEGIN;

SELECT assert_function('jwt_public.current_ip_address()'::regprocedure);

ROLLBACK;
