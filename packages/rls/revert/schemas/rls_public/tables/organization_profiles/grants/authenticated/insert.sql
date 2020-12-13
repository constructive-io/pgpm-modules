-- Revert: schemas/rls_public/tables/organization_profiles/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE "rls_public".organization_profiles FROM authenticated;
COMMIT;  

