-- Revert: schemas/rls_public/tables/organization_settings/grants/authenticated/delete from pg

BEGIN;
REVOKE DELETE ON TABLE "rls_public".organization_settings FROM authenticated;
COMMIT;  

