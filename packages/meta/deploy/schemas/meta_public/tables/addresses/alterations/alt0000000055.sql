-- Deploy: schemas/meta_public/tables/addresses/alterations/alt0000000055 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/addresses/table

BEGIN;
ALTER TABLE "meta_public".addresses ADD CONSTRAINT addresses_other_chk CHECK (character_length(other) <= 120);
COMMIT;
