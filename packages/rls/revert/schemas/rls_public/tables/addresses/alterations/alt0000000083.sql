-- Revert: schemas/rls_public/tables/addresses/alterations/alt0000000083 from pg

BEGIN;
ALTER TABLE "rls_public".addresses DROP CONSTRAINT addresses_city_chk;
COMMIT;  

