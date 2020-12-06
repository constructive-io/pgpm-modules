-- Revert: schemas/meta_public/alterations/alt0000000075 from pg

BEGIN;
COMMENT ON CONSTRAINT organization_settings_phone_id_fkey ON "meta_public".organization_settings IS NULL;
COMMIT;  

