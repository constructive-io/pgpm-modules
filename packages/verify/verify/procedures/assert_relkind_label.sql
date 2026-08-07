-- Verify procedures/assert_relkind_label on pg

BEGIN;

SELECT assert_function('assert_relkind_label("char")'::regprocedure);

ROLLBACK;
