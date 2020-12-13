-- Revert: schemas/collections_public/tables/trigger/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.trigger FROM authenticated;
COMMIT;  

