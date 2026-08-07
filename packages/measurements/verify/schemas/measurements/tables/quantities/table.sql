-- Verify schemas/measurements/tables/quantities/table on pg

BEGIN;

SELECT assert_table('measurements.quantities'::regclass);

ROLLBACK;
