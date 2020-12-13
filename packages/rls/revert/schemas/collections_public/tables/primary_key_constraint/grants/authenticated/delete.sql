-- Revert: schemas/collections_public/tables/primary_key_constraint/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.primary_key_constraint FROM authenticated;
COMMIT;  

