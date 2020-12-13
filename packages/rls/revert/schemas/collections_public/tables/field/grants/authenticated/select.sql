-- Revert: schemas/collections_public/tables/field/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.field FROM authenticated;
COMMIT;  

