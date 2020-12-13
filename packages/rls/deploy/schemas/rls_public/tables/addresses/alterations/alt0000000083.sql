-- Deploy: schemas/rls_public/tables/addresses/alterations/alt0000000083 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/addresses/table

BEGIN;
ALTER TABLE "rls_public".addresses ADD CONSTRAINT addresses_city_chk CHECK (character_length(city) <= 120);
COMMIT;
