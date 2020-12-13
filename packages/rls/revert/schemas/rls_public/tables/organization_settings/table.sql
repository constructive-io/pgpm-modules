-- Revert: schemas/rls_public/tables/organization_settings/table from pg

BEGIN;
DROP TABLE "rls_public".organization_settings;
COMMIT;  

