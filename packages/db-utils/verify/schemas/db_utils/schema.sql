-- Verify schemas/db_utils/schema  on pg

BEGIN;

SELECT assert_schema('db_utils'::regnamespace);

ROLLBACK;
