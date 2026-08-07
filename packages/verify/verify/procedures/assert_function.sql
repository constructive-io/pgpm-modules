-- Verify procedures/assert_function on pg

BEGIN;

SELECT assert_function('assert_function(regprocedure, regtype, bool, bool, text)'::regprocedure);

ROLLBACK;
