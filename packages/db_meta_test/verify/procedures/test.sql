-- Verify procedures/test  on pg

BEGIN;

SELECT verify_function ('public.test');

ROLLBACK;
