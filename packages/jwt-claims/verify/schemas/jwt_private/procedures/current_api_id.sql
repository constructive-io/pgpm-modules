-- Verify schemas/jwt_private/procedures/current_api_id on pg

BEGIN;

SELECT assert_function('jwt_private.current_api_id()'::regprocedure);

ROLLBACK;
