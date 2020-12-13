-- Revert: schemas/rls_public/tables/user_settings/constraints/user_settings_user_id_key from pg

BEGIN;


ALTER TABLE "rls_public".user_settings 
    DROP CONSTRAINT user_settings_user_id_key;

COMMIT;  

