-- Revert: schemas/rls_public/tables/organization_profiles/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_public".organization_profiles FROM authenticated;
COMMIT;  

