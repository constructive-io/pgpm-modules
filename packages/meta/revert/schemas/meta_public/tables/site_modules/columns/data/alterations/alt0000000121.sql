-- Revert: schemas/meta_public/tables/site_modules/columns/data/alterations/alt0000000121 from pg

BEGIN;


ALTER TABLE "meta_public".site_modules 
    ALTER COLUMN data DROP NOT NULL;


COMMIT;  

