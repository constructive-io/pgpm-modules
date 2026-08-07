-- Verify procedures/assert_trigger on pg

BEGIN;

SELECT assert_function('assert_trigger(regclass, name, regproc, int4, bool)'::regprocedure);

ROLLBACK;
