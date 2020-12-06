-- Deploy: schemas/meta_public/tables/site_metadata/alterations/alt0000000134 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/site_metadata/table

BEGIN;
ALTER TABLE "meta_public".site_metadata ADD CONSTRAINT site_metadata_description_chk CHECK (character_length(description) <= 120);
COMMIT;
