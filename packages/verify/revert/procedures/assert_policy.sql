-- Revert procedures/assert_policy from pg

BEGIN;

DROP FUNCTION assert_policy(regclass, name, text, bool, bool, bool);

COMMIT;
