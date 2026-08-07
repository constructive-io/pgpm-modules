-- Revert procedures/assert_view_rule from pg

BEGIN;

DROP FUNCTION assert_view_rule(regclass, name, text);

COMMIT;
