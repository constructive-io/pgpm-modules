-- Revert procedures/assert_function from pg

BEGIN;

DROP FUNCTION assert_function(regprocedure, regtype, bool, bool, text);

COMMIT;
