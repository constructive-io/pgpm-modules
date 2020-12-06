-- Deploy: schemas/meta_public/tables/addresses/alterations/alt0000000048 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/addresses/table

BEGIN;
ALTER TABLE "meta_public".addresses ADD CONSTRAINT addresses_address_line_1_chk CHECK (character_length(address_line_1) <= 120);
COMMIT;
