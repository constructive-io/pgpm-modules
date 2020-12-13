-- Revert: schemas/rls_public/tables/organization_profiles/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_public".organization_profiles FROM authenticated;
COMMIT;  

