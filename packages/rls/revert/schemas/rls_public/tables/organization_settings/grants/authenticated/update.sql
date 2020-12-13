-- Revert: schemas/rls_public/tables/organization_settings/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE "rls_public".organization_settings FROM authenticated;
COMMIT;  

