-- Verify procedures/assert_index on pg

BEGIN;

SELECT assert_function('assert_index(regclass, regclass, bool)'::regprocedure);

ROLLBACK;
