-- Revert procedures/assert_policy_command_label from pg

BEGIN;

DROP FUNCTION assert_policy_command_label("char");

COMMIT;
