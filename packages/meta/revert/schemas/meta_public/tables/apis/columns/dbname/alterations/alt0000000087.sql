-- Revert: schemas/meta_public/tables/apis/columns/dbname/alterations/alt0000000087 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN dbname DROP NOT NULL;


COMMIT;  

