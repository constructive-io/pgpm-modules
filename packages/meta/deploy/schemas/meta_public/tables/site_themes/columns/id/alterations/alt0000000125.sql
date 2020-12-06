-- Deploy: schemas/meta_public/tables/site_themes/columns/id/alterations/alt0000000125 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/site_themes/table
-- requires: schemas/meta_public/tables/site_themes/columns/id/column

BEGIN;

ALTER TABLE "meta_public".site_themes 
    ALTER COLUMN id SET NOT NULL;
COMMIT;
