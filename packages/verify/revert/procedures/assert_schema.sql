-- Revert procedures/assert_schema from pg

BEGIN;

DROP FUNCTION assert_schema(regnamespace);

COMMIT;
