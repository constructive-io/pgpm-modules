-- Deploy: schemas/meta_public/tables/site_metadata/columns/id/alterations/alt0000000131 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/site_metadata/table
-- requires: schemas/meta_public/tables/site_metadata/columns/id/column

BEGIN;

ALTER TABLE "meta_public".site_metadata 
    ALTER COLUMN id SET NOT NULL;
COMMIT;
