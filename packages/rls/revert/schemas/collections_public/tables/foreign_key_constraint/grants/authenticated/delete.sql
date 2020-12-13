-- Revert: schemas/collections_public/tables/foreign_key_constraint/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.foreign_key_constraint FROM authenticated;
COMMIT;  

