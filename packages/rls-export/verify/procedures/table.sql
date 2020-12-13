-- Verify procedures/table  on pg

BEGIN;

SELECT verify_function ('public.table');

ROLLBACK;
