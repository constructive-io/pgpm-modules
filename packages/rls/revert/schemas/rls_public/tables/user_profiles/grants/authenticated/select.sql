-- Revert: schemas/rls_public/tables/user_profiles/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".user_profiles FROM authenticated;
COMMIT;  

