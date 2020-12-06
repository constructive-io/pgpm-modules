-- Deploy: schemas/meta_public/tables/addresses/alterations/alt0000000050 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/addresses/table

BEGIN;
ALTER TABLE "meta_public".addresses ADD CONSTRAINT addresses_address_line_3_chk CHECK (character_length(address_line_3) <= 120);
COMMIT;
