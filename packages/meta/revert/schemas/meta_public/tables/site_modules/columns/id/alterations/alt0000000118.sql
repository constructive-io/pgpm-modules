-- Revert: schemas/meta_public/tables/site_modules/columns/id/alterations/alt0000000118 from pg

BEGIN;


ALTER TABLE "meta_public".site_modules 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  

