-- Deploy: schemas/meta_public/tables/addresses/columns/id/alterations/alt0000000046 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/addresses/table
-- requires: schemas/meta_public/tables/addresses/columns/id/column

BEGIN;

ALTER TABLE "meta_public".addresses 
    ALTER COLUMN id SET NOT NULL;
COMMIT;
