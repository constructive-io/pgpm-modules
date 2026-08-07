-- Verify procedures/assert_view on pg

BEGIN;

SELECT assert_function('assert_view(regclass, bool, bool)'::regprocedure);

ROLLBACK;
