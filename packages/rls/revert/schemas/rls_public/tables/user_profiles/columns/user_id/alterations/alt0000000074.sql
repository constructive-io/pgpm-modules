-- Revert: schemas/rls_public/tables/user_profiles/columns/user_id/alterations/alt0000000074 from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles 
    ALTER COLUMN user_id DROP NOT NULL;


COMMIT;  

