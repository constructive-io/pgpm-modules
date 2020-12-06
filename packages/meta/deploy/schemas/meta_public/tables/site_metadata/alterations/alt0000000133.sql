-- Deploy: schemas/meta_public/tables/site_metadata/alterations/alt0000000133 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/site_metadata/table

BEGIN;
ALTER TABLE "meta_public".site_metadata ADD CONSTRAINT site_metadata_title_chk CHECK (character_length(title) <= 120);
COMMIT;
