-- Revert procedures/assert_table from pg

BEGIN;

DROP FUNCTION assert_table(regclass, bool, bool);

COMMIT;
