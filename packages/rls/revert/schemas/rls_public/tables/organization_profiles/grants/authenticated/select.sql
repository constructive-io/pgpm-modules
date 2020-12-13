-- Revert: schemas/rls_public/tables/organization_profiles/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".organization_profiles FROM authenticated;
COMMIT;  

