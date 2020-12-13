-- Revert: schemas/rls_public/tables/user_settings/alterations/alt0000000100 from pg

BEGIN;
ALTER TABLE "rls_public".user_settings DROP CONSTRAINT user_settings_last_name_chk;
COMMIT;  

