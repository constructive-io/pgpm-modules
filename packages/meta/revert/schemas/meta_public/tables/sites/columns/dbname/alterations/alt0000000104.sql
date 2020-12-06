-- Revert: schemas/meta_public/tables/sites/columns/dbname/alterations/alt0000000104 from pg

BEGIN;


ALTER TABLE "meta_public".sites 
    ALTER COLUMN dbname DROP DEFAULT;

COMMIT;  

