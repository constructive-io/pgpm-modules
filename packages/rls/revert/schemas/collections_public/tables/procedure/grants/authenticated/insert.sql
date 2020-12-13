-- Revert: schemas/collections_public/tables/procedure/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.procedure FROM authenticated;
COMMIT;  

