-- Revert: schemas/collections_public/tables/unique_constraint/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.unique_constraint FROM authenticated;
COMMIT;  

