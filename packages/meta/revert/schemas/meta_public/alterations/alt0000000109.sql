-- Revert: schemas/meta_public/alterations/alt0000000109 from pg

BEGIN;
COMMENT ON CONSTRAINT sites_owner_id_fkey ON "meta_public".sites IS NULL;
COMMIT;  

