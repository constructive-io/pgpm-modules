-- Revert: schemas/meta_public/tables/site_themes/columns/site_id/alterations/alt0000000128 from pg

BEGIN;


ALTER TABLE "meta_public".site_themes 
    ALTER COLUMN site_id DROP NOT NULL;


COMMIT;  

