-- Verify schemas/jwt_private/procedures/require_entity_type on pg

BEGIN;

SELECT assert_function('jwt_private.require_entity_type()'::regprocedure);

ROLLBACK;
