-- Revert: schemas/rls_public/tables/organization_settings/grants/authenticated/select from pg

BEGIN;
REVOKE SELECT ON TABLE "rls_public".organization_settings FROM authenticated;
COMMIT;  

