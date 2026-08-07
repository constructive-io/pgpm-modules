-- Verify procedures/assert_type on pg

BEGIN;

SELECT assert_function('public.assert_type(regtype, "char")'::regprocedure);

ROLLBACK;
