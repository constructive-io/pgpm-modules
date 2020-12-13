-- Revert: schemas/rls_public/tables/addresses/alterations/alt0000000087 from pg

BEGIN;
ALTER TABLE "rls_public".addresses DROP CONSTRAINT addresses_other_chk;
COMMIT;  

