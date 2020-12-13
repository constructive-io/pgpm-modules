-- Revert: schemas/collections_public/tables/primary_key_constraint/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.primary_key_constraint FROM authenticated;
COMMIT;  

