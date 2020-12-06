-- Deploy: schemas/meta_public/tables/addresses/alterations/alt0000000054 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/addresses/table

BEGIN;
ALTER TABLE "meta_public".addresses ADD CONSTRAINT addresses_postcode_chk CHECK (character_length(postcode) <= 24);
COMMIT;
