-- Revert: schemas/meta_public/tables/sites/columns/dbname/alterations/alt0000000103 from pg

BEGIN;


ALTER TABLE "meta_public".sites 
    ALTER COLUMN dbname DROP NOT NULL;


COMMIT;  

