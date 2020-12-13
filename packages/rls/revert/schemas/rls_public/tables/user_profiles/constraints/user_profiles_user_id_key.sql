-- Revert: schemas/rls_public/tables/user_profiles/constraints/user_profiles_user_id_key from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles 
    DROP CONSTRAINT user_profiles_user_id_key;

COMMIT;  

