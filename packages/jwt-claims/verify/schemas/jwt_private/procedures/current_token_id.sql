-- Verify schemas/jwt_private/procedures/current_token_id  on pg

BEGIN;

SELECT assert_function('jwt_private.current_token_id()'::regprocedure);

ROLLBACK;

