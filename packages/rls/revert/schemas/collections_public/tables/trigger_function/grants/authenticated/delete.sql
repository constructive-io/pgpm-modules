-- Revert: schemas/collections_public/tables/trigger_function/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.trigger_function FROM authenticated;
COMMIT;  

