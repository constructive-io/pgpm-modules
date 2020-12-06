-- Deploy: schemas/meta_public/tables/api_modules/columns/name/alterations/alt0000000113 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/api_modules/table
-- requires: schemas/meta_public/tables/api_modules/columns/name/column

BEGIN;

ALTER TABLE "meta_public".api_modules 
    ALTER COLUMN name SET NOT NULL;
COMMIT;
