-- Revert: schemas/meta_public/tables/api_modules/columns/name/alterations/alt0000000113 from pg

BEGIN;


ALTER TABLE "meta_public".api_modules 
    ALTER COLUMN name DROP NOT NULL;


COMMIT;  

