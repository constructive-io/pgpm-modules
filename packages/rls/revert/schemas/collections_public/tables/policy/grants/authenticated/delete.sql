-- Revert: schemas/collections_public/tables/policy/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE collections_public.policy FROM authenticated;
COMMIT;  

