-- Revert: schemas/meta_public/alterations/alt0000000076 from pg

BEGIN;
COMMENT ON CONSTRAINT organization_settings_organization_id_key ON "meta_public".organization_settings IS NULL;
COMMIT;  

