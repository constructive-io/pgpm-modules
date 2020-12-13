-- Revert: schemas/collections_public/tables/policy/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE collections_public.policy FROM authenticated;
COMMIT;  

