-- Revert: schemas/rls_public/tables/user_profiles/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_public".user_profiles FROM authenticated;
COMMIT;  

