-- Revert: schemas/meta_public/tables/apps/columns/id/alterations/alt0000000139 from pg

BEGIN;


ALTER TABLE "meta_public".apps 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  

