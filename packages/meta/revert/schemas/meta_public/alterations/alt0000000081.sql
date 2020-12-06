-- Revert: schemas/meta_public/alterations/alt0000000081 from pg

BEGIN;
COMMENT ON CONSTRAINT domains_owner_id_fkey ON "meta_public".domains IS NULL;
COMMIT;  

