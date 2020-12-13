-- Revert: schemas/rls_public/tables/addresses/alterations/alt0000000085 from pg

BEGIN;
ALTER TABLE "rls_public".addresses DROP CONSTRAINT addresses_county_province_chk;
COMMIT;  

