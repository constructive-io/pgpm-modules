-- Verify schemas/measurements/schema  on pg

BEGIN;

SELECT assert_schema('measurements'::regnamespace);

ROLLBACK;
