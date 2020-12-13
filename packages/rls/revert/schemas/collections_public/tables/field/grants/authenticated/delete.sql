-- Revert: schemas/collections_public/tables/field/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.field FROM authenticated;
COMMIT;  

