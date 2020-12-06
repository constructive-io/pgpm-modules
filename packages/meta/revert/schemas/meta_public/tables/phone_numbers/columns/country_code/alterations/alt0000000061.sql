-- Revert: schemas/meta_public/tables/phone_numbers/columns/country_code/alterations/alt0000000061 from pg

BEGIN;


ALTER TABLE "meta_public".phone_numbers 
    ALTER COLUMN country_code DROP NOT NULL;


COMMIT;  

