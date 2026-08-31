-- Verify schemas/jwt_private/procedures/assert_attribution on pg

BEGIN;

SELECT assert_function('jwt_private.assert_attribution(uuid, uuid, text)'::regprocedure);

ROLLBACK;
