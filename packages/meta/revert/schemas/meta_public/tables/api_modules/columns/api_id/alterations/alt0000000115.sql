-- Revert: schemas/meta_public/tables/api_modules/columns/api_id/alterations/alt0000000115 from pg

BEGIN;


ALTER TABLE "meta_public".api_modules 
    ALTER COLUMN api_id DROP NOT NULL;


COMMIT;  

