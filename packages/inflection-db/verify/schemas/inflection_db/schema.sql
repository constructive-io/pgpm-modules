-- Verify schemas/inflection_db/schema  on pg

BEGIN;

SELECT assert_schema('inflection_db'::regnamespace);

ROLLBACK;
