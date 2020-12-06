-- Revert: schemas/meta_public/tables/phone_numbers/columns/id/alterations/alt0000000059 from pg

BEGIN;


ALTER TABLE "meta_public".phone_numbers 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  

