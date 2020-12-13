-- Revert: schemas/rls_public/tables/user_profiles/columns/id/column from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles DROP COLUMN id;
COMMIT;  

