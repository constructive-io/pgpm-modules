-- Verify schemas/faker/schema  on pg

BEGIN;

SELECT assert_schema('faker'::regnamespace);

ROLLBACK;
