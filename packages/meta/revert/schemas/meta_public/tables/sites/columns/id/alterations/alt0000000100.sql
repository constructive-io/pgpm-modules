-- Revert: schemas/meta_public/tables/sites/columns/id/alterations/alt0000000100 from pg

BEGIN;


ALTER TABLE "meta_public".sites 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  

