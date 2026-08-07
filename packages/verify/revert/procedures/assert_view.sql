-- Revert procedures/assert_view from pg

BEGIN;

DROP FUNCTION assert_view(regclass, bool, bool);

COMMIT;
