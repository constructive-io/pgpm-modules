-- Revert: schemas/collections_public/tables/field/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.field FROM authenticated;
COMMIT;  

