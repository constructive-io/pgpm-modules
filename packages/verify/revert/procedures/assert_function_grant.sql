-- Revert procedures/assert_function_grant from pg

BEGIN;

DROP FUNCTION assert_function_grant(regprocedure, name, text, bool);

COMMIT;
