-- Verify procedures/assert_policy_command_label on pg

BEGIN;

SELECT assert_function('assert_policy_command_label("char")'::regprocedure);

ROLLBACK;
