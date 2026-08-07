-- Verify procedures/assert_domain on pg

BEGIN;

SELECT assert_function('public.assert_domain(regtype, regtype, boolean, int)'::regprocedure);

ROLLBACK;
