-- Verify schemas/function_resolution/schema  on pg

BEGIN;

SELECT assert_schema('function_resolution'::regnamespace);

ROLLBACK;
