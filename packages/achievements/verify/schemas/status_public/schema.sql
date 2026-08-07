-- Verify schemas/status_public/schema  on pg

BEGIN;

SELECT assert_schema('status_public'::regnamespace);

ROLLBACK;
