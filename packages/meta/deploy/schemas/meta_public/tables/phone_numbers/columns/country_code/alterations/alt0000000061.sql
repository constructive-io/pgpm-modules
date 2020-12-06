-- Deploy: schemas/meta_public/tables/phone_numbers/columns/country_code/alterations/alt0000000061 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/phone_numbers/table
-- requires: schemas/meta_public/tables/phone_numbers/columns/country_code/column

BEGIN;

ALTER TABLE "meta_public".phone_numbers 
    ALTER COLUMN country_code SET NOT NULL;
COMMIT;
