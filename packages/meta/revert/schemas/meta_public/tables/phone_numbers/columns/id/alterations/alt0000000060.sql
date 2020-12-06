-- Revert: schemas/meta_public/tables/phone_numbers/columns/id/alterations/alt0000000060 from pg

BEGIN;


ALTER TABLE "meta_public".phone_numbers 
    ALTER COLUMN id DROP DEFAULT;

COMMIT;  

