-- Revert: schemas/collections_public/tables/trigger_function/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.trigger_function FROM authenticated;
COMMIT;  

