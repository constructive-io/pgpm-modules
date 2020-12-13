-- Revert: schemas/collections_public/tables/field/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.field FROM authenticated;
COMMIT;  

