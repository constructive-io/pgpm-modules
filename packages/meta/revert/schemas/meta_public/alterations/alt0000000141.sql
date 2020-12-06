-- Revert: schemas/meta_public/alterations/alt0000000141 from pg

BEGIN;
COMMENT ON CONSTRAINT apps_site_id_fkey ON "meta_public".apps IS NULL;
COMMIT;  

