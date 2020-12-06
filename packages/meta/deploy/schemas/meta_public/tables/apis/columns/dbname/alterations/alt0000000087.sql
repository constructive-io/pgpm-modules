-- Deploy: schemas/meta_public/tables/apis/columns/dbname/alterations/alt0000000087 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/apis/table
-- requires: schemas/meta_public/tables/apis/columns/dbname/column

BEGIN;

ALTER TABLE "meta_public".apis 
    ALTER COLUMN dbname SET NOT NULL;
COMMIT;
