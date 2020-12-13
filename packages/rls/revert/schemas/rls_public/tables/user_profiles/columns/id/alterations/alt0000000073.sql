-- Revert: schemas/rls_public/tables/user_profiles/columns/id/alterations/alt0000000073 from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  

