-- Revert: schemas/rls_public/tables/addresses/alterations/alt0000000081 from pg

BEGIN;
ALTER TABLE "rls_public".addresses DROP CONSTRAINT addresses_address_line_2_chk;
COMMIT;  

