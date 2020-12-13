-- Revert: schemas/collections_public/tables/primary_key_constraint/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.primary_key_constraint FROM authenticated;
COMMIT;  

