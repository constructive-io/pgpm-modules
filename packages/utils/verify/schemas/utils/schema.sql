-- Verify schemas/utils/schema  on pg

BEGIN;

SELECT assert_schema('utils'::regnamespace);

ROLLBACK;
