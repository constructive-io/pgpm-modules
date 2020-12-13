-- Revert: schemas/rls_public/tables/user_profiles/columns/user_id/column from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles DROP COLUMN user_id;
COMMIT;  

