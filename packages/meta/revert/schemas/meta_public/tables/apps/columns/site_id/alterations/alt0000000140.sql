-- Revert: schemas/meta_public/tables/apps/columns/site_id/alterations/alt0000000140 from pg

BEGIN;


ALTER TABLE "meta_public".apps 
    ALTER COLUMN site_id DROP NOT NULL;


COMMIT;  

