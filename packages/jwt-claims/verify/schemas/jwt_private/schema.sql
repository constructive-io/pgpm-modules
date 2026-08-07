-- Verify schemas/jwt_private/schema  on pg

BEGIN;

SELECT assert_schema('jwt_private'::regnamespace);

ROLLBACK;
