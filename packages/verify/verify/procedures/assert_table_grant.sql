-- Verify procedures/assert_table_grant on pg

BEGIN;

SELECT assert_function('assert_table_grant(regclass, name, text, text[], bool)'::regprocedure);

ROLLBACK;
