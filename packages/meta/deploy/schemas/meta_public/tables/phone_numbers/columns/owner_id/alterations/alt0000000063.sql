-- Deploy: schemas/meta_public/tables/phone_numbers/columns/owner_id/alterations/alt0000000063 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/phone_numbers/table
-- requires: schemas/meta_public/tables/phone_numbers/columns/owner_id/column

BEGIN;

ALTER TABLE "meta_public".phone_numbers 
    ALTER COLUMN owner_id SET NOT NULL;
COMMIT;
