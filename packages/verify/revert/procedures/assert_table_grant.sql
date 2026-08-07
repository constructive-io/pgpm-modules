-- Revert procedures/assert_table_grant from pg

BEGIN;

DROP FUNCTION assert_table_grant(regclass, name, text, text[], bool);

COMMIT;
