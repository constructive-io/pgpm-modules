-- Revert: schemas/collections_public/tables/procedure/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.procedure FROM authenticated;
COMMIT;  

