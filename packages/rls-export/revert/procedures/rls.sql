-- Revert procedures/rls from pg

BEGIN;

DROP FUNCTION public.rls;

COMMIT;
