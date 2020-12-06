-- Revert: schemas/meta_public/tables/apis/columns/id/alterations/alt0000000085 from pg

BEGIN;


ALTER TABLE "meta_public".apis 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  

