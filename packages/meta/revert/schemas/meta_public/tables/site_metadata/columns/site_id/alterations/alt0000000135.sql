-- Revert: schemas/meta_public/tables/site_metadata/columns/site_id/alterations/alt0000000135 from pg

BEGIN;


ALTER TABLE "meta_public".site_metadata 
    ALTER COLUMN site_id DROP NOT NULL;


COMMIT;  

