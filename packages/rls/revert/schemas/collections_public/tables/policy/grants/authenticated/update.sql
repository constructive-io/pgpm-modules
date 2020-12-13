-- Revert: schemas/collections_public/tables/policy/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.policy FROM authenticated;
COMMIT;  

