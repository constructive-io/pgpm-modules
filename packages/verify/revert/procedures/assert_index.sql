-- Revert procedures/assert_index from pg

BEGIN;

DROP FUNCTION assert_index(regclass, regclass, bool);

COMMIT;
