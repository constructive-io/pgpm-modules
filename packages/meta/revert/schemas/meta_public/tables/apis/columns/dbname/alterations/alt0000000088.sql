-- Revert: schemas/meta_public/tables/apis/columns/dbname/alterations/alt0000000088 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN dbname DROP DEFAULT;

COMMIT;  

