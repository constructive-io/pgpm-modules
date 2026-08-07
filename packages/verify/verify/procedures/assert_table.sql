-- Verify procedures/assert_table on pg

BEGIN;

SELECT assert_function('assert_table(regclass, bool, bool)'::regprocedure);

ROLLBACK;
