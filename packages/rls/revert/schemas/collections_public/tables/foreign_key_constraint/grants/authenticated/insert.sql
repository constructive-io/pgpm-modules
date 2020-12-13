-- Revert: schemas/collections_public/tables/foreign_key_constraint/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.foreign_key_constraint FROM authenticated;
COMMIT;  

