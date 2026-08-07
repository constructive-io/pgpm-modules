-- Verify schemas/ctx/schema on pg

BEGIN;

SELECT assert_schema('ctx'::regnamespace);

ROLLBACK;

