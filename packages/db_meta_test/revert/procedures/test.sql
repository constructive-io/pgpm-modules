-- Revert procedures/test from pg

BEGIN;

DROP FUNCTION public.test;

COMMIT;
