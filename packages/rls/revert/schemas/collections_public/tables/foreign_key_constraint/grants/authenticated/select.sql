-- Revert: schemas/collections_public/tables/foreign_key_constraint/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.foreign_key_constraint FROM authenticated;
COMMIT;  

