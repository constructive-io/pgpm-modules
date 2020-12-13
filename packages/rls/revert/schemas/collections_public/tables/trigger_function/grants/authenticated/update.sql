-- Revert: schemas/collections_public/tables/trigger_function/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.trigger_function FROM authenticated;
COMMIT;  

