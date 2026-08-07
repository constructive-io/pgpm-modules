-- Verify procedures/assert_view_rule on pg

BEGIN;

SELECT assert_function('assert_view_rule(regclass, name, text)'::regprocedure);

ROLLBACK;
