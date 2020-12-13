-- Revert: schemas/rls_public/tables/organization_profiles/table from pg

BEGIN;
DROP TABLE "rls_public".organization_profiles;
COMMIT;  

