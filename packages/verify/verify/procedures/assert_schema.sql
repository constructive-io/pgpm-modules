-- Verify procedures/assert_schema on pg

BEGIN;

SELECT assert_function('assert_schema(regnamespace)'::regprocedure);

ROLLBACK;
