-- Revert: schemas/meta_public/tables/site_metadata/alterations/alt0000000134 from pg

BEGIN;
ALTER TABLE "meta_public".site_metadata DROP CONSTRAINT site_metadata_description_chk;
COMMIT;  

