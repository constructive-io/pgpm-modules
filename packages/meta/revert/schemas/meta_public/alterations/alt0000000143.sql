-- Revert: schemas/meta_public/alterations/alt0000000143 from pg

BEGIN;
COMMENT ON CONSTRAINT apps_site_id_key ON "meta_public".apps IS NULL;
COMMIT;  

