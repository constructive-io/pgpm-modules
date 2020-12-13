-- Revert: schemas/collections_public/tables/primary_key_constraint/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.primary_key_constraint FROM authenticated;
COMMIT;  

