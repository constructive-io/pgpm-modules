-- Revert: schemas/rls_public/tables/user_profiles/columns/display_name/column from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles DROP COLUMN display_name;
COMMIT;  

