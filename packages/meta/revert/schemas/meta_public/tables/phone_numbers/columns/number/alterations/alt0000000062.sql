-- Revert: schemas/meta_public/tables/phone_numbers/columns/number/alterations/alt0000000062 from pg

BEGIN;


ALTER TABLE "meta_public".phone_numbers 
    ALTER COLUMN number DROP NOT NULL;


COMMIT;  

