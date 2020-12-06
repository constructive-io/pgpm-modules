-- Revert: schemas/meta_public/tables/api_modules/columns/data/alterations/alt0000000114 from pg

BEGIN;


ALTER TABLE "meta_public".api_modules 
    ALTER COLUMN data DROP NOT NULL;


COMMIT;  

