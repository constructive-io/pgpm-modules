-- Revert: schemas/rls_public/tables/addresses/alterations/alt0000000086 from pg

BEGIN;
ALTER TABLE "rls_public".addresses DROP CONSTRAINT addresses_postcode_chk;
COMMIT;  

