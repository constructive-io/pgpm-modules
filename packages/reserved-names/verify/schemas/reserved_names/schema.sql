-- Verify schemas/reserved_names/schema on pg

BEGIN;

SELECT assert_schema('reserved_names'::regnamespace);

ROLLBACK;
