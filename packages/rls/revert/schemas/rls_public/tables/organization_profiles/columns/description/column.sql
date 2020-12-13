-- Revert: schemas/rls_public/tables/organization_profiles/columns/description/column from pg

BEGIN;


ALTER TABLE "rls_public".organization_profiles DROP COLUMN description;
COMMIT;  

