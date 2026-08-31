-- Verify schemas/jwt_private/procedures/require_entity_id on pg

BEGIN;

SELECT assert_function('jwt_private.require_entity_id()'::regprocedure);

ROLLBACK;
