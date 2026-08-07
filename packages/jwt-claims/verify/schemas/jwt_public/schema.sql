-- Verify schemas/jwt_public/schema  on pg

BEGIN;

SELECT assert_schema('jwt_public'::regnamespace);

ROLLBACK;
