-- Revert: schemas/meta_public/tables/addresses/columns/id/alterations/alt0000000047 from pg

BEGIN;


ALTER TABLE "meta_public".addresses 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  

