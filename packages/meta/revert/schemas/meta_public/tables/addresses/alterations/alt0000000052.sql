-- Revert: schemas/meta_public/tables/addresses/alterations/alt0000000052 from pg

BEGIN;
ALTER TABLE "meta_public".addresses DROP CONSTRAINT addresses_state_chk;
COMMIT;  

