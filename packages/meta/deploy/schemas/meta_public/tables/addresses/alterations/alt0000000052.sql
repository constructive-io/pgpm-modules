-- Deploy: schemas/meta_public/tables/addresses/alterations/alt0000000052 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/addresses/table

BEGIN;
ALTER TABLE "meta_public".addresses ADD CONSTRAINT addresses_state_chk CHECK (character_length(state) <= 120);
COMMIT;
