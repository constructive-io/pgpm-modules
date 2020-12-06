-- Revert: schemas/meta_public/tables/addresses/alterations/alt0000000049 from pg

BEGIN;
ALTER TABLE "meta_public".addresses DROP CONSTRAINT addresses_address_line_2_chk;
COMMIT;  

