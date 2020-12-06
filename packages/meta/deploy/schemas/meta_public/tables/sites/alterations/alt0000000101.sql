-- Deploy: schemas/meta_public/tables/sites/alterations/alt0000000101 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/sites/table

BEGIN;
ALTER TABLE "meta_public".sites ADD CONSTRAINT sites_title_chk CHECK (character_length(title) <= 120);
COMMIT;
