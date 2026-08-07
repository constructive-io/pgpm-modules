-- Revert procedures/assert_table_security from pg

BEGIN;

DROP FUNCTION assert_table_security(regclass, bool, bool);

COMMIT;
