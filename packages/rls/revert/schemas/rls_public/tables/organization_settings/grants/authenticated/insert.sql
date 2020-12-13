-- Revert: schemas/rls_public/tables/organization_settings/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE "rls_public".organization_settings FROM authenticated;
COMMIT;  

