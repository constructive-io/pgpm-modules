-- Revert: schemas/meta_public/tables/addresses/alterations/alt0000000053 from pg

BEGIN;
ALTER TABLE "meta_public".addresses DROP CONSTRAINT addresses_county_province_chk;
COMMIT;  

