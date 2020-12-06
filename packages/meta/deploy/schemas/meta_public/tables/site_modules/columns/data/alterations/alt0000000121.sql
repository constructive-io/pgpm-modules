-- Deploy: schemas/meta_public/tables/site_modules/columns/data/alterations/alt0000000121 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/site_modules/table
-- requires: schemas/meta_public/tables/site_modules/columns/data/column

BEGIN;

ALTER TABLE "meta_public".site_modules 
    ALTER COLUMN data SET NOT NULL;
COMMIT;
