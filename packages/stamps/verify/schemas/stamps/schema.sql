-- Verify schemas/stamps/schema  on pg

BEGIN;

SELECT assert_schema('stamps'::regnamespace);

ROLLBACK;
