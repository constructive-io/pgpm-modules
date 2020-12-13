-- Revert: schemas/collections_public/tables/unique_constraint/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.unique_constraint FROM authenticated;
COMMIT;  

