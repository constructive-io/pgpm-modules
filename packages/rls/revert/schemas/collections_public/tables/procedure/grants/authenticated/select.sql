-- Revert: schemas/collections_public/tables/procedure/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.procedure FROM authenticated;
COMMIT;  

