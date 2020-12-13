-- Revert: schemas/collections_public/tables/unique_constraint/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.unique_constraint FROM authenticated;
COMMIT;  

