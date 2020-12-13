-- Revert: schemas/rls_public/alterations/alt0000000075 from pg

BEGIN;
COMMENT ON CONSTRAINT user_profiles_user_id_fkey ON "rls_public".user_profiles IS NULL;
COMMIT;  

