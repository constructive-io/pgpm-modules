-- Revert: schemas/meta_public/tables/domains/columns/id/alterations/alt0000000079 from pg

BEGIN;


ALTER TABLE "meta_public".domains 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  

