-- Revert: schemas/collections_public/tables/trigger/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.trigger FROM authenticated;
COMMIT;  

