-- Verify schemas/jwt_private/procedures/require_database_id on pg

BEGIN;

SELECT assert_function('jwt_private.require_database_id()'::regprocedure);

ROLLBACK;
