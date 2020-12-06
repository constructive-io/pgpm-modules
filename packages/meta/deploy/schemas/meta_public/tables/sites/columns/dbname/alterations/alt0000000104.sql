-- Deploy: schemas/meta_public/tables/sites/columns/dbname/alterations/alt0000000104 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/sites/table
-- requires: schemas/meta_public/tables/sites/columns/dbname/column

BEGIN;

ALTER TABLE "meta_public".sites 
    ALTER COLUMN dbname SET DEFAULT current_database();
COMMIT;
