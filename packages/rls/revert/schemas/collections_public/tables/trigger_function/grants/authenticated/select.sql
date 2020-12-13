-- Revert: schemas/collections_public/tables/trigger_function/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.trigger_function FROM authenticated;
COMMIT;  

