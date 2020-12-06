-- Deploy: schemas/meta_public/tables/site_modules/columns/site_id/alterations/alt0000000122 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/site_modules/table
-- requires: schemas/meta_public/tables/site_modules/columns/site_id/column

BEGIN;

ALTER TABLE "meta_public".site_modules 
    ALTER COLUMN site_id SET NOT NULL;
COMMIT;
