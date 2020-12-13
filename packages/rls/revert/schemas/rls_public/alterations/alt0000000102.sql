-- Revert: schemas/rls_public/alterations/alt0000000102 from pg

BEGIN;
COMMENT ON CONSTRAINT user_settings_user_id_fkey ON "rls_public".user_settings IS NULL;
COMMIT;  

