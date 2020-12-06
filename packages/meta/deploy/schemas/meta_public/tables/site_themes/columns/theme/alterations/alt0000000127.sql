-- Deploy: schemas/meta_public/tables/site_themes/columns/theme/alterations/alt0000000127 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/site_themes/table
-- requires: schemas/meta_public/tables/site_themes/columns/theme/column

BEGIN;

ALTER TABLE "meta_public".site_themes 
    ALTER COLUMN theme SET NOT NULL;
COMMIT;
