-- Verify procedures/assert_function_grant on pg

BEGIN;

SELECT assert_function('public.assert_function_grant(regprocedure, name, text, boolean)'::regprocedure);

ROLLBACK;
