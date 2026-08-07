-- Verify procedures/assert_policy on pg

BEGIN;

SELECT assert_function('assert_policy(regclass, name, text, bool, bool, bool)'::regprocedure);

ROLLBACK;
