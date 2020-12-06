-- Deploy: schemas/meta_public/tables/api_modules/columns/api_id/alterations/alt0000000115 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/api_modules/table
-- requires: schemas/meta_public/tables/api_modules/columns/api_id/column

BEGIN;

ALTER TABLE "meta_public".api_modules 
    ALTER COLUMN api_id SET NOT NULL;
COMMIT;
