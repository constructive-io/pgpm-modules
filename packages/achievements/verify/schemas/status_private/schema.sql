-- Verify schemas/status_private/schema  on pg

BEGIN;

SELECT assert_schema('status_private'::regnamespace);

ROLLBACK;
