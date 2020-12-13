-- Deploy: schemas/rls_public/tables/addresses/alterations/alt0000000084 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table

BEGIN;
ALTER TABLE "rls_public".addresses ADD CONSTRAINT addresses_state_chk CHECK (character_length(state) <= 120);
COMMIT;
