-- Deploy: schemas/meta_public/tables/phone_numbers/columns/number/alterations/alt0000000062 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/phone_numbers/table
-- requires: schemas/meta_public/tables/phone_numbers/columns/number/column

BEGIN;

ALTER TABLE "meta_public".phone_numbers 
    ALTER COLUMN number SET NOT NULL;
COMMIT;
