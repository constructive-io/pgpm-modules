-- Verify procedures/rls  on pg

BEGIN;

SELECT verify_function ('public.rls');

ROLLBACK;
