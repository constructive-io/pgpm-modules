-- Revert: schemas/rls_public/tables/organization_profiles/columns/profile_picture/column from pg

BEGIN;


ALTER TABLE "rls_public".organization_profiles DROP COLUMN profile_picture;
COMMIT;  

