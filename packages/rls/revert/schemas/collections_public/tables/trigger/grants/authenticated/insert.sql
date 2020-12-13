-- Revert: schemas/collections_public/tables/trigger/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.trigger FROM authenticated;
COMMIT;  

