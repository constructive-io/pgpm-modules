-- Deploy: schemas/rls_public/tables/addresses/alterations/alt0000000080 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table

BEGIN;
ALTER TABLE "rls_public".addresses ADD CONSTRAINT addresses_address_line_1_chk CHECK (character_length(address_line_1) <= 120);
COMMIT;
