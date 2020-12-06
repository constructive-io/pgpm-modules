-- Revert: schemas/meta_public/alterations/alt0000000064 from pg

BEGIN;
COMMENT ON CONSTRAINT phone_numbers_owner_id_fkey ON "meta_public".phone_numbers IS NULL;
COMMIT;  

