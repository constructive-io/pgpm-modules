-- Revert: schemas/collections_public/tables/policy/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.policy FROM authenticated;
COMMIT;  

