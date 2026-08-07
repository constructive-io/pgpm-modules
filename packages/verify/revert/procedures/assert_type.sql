-- Revert procedures/assert_type from pg

BEGIN;

DROP FUNCTION assert_type(regtype, "char");

COMMIT;
