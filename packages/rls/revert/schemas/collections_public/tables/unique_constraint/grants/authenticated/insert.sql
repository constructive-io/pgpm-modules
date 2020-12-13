-- Revert: schemas/collections_public/tables/unique_constraint/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.unique_constraint FROM authenticated;
COMMIT;  

