-- Revert procedures/table from pg

BEGIN;

DROP FUNCTION public.table;

COMMIT;
