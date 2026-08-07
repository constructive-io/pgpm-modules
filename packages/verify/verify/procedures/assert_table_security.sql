-- Verify procedures/assert_table_security on pg

BEGIN;

SELECT assert_function('assert_table_security(regclass, bool, bool)'::regprocedure);

ROLLBACK;
