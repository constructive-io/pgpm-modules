-- Deploy: schemas/meta_public/tables/phone_numbers/columns/id/alterations/alt0000000059 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/phone_numbers/table
-- requires: schemas/meta_public/tables/phone_numbers/columns/id/column

BEGIN;

ALTER TABLE "meta_public".phone_numbers 
    ALTER COLUMN id SET NOT NULL;
COMMIT;
