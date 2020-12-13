-- Deploy: schemas/rls_public/tables/addresses/alterations/alt0000000086 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table

BEGIN;
ALTER TABLE "rls_public".addresses ADD CONSTRAINT addresses_postcode_chk CHECK (character_length(postcode) <= 24);
COMMIT;
