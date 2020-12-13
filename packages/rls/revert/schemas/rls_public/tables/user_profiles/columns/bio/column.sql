-- Revert: schemas/rls_public/tables/user_profiles/columns/bio/column from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles DROP COLUMN bio;
COMMIT;  

