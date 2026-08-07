-- Revert procedures/assert_relkind_label from pg

BEGIN;

DROP FUNCTION assert_relkind_label("char");

COMMIT;
