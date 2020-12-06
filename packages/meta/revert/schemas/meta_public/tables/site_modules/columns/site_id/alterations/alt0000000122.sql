-- Revert: schemas/meta_public/tables/site_modules/columns/site_id/alterations/alt0000000122 from pg

BEGIN;


ALTER TABLE "meta_public".site_modules 
    ALTER COLUMN site_id DROP NOT NULL;


COMMIT;  

