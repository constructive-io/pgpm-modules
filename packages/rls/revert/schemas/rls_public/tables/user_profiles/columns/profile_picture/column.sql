-- Revert: schemas/rls_public/tables/user_profiles/columns/profile_picture/column from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles DROP COLUMN profile_picture;
COMMIT;  

