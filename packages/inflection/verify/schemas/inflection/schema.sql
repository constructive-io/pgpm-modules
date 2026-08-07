-- Verify schemas/inflection/schema  on pg

BEGIN;

SELECT assert_schema('inflection'::regnamespace);

ROLLBACK;
