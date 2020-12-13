-- Revert: schemas/rls_public/tables/user_profiles/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_public".user_profiles FROM authenticated;
COMMIT;  

