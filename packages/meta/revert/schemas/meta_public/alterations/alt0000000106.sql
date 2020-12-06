-- Revert: schemas/meta_public/alterations/alt0000000106 from pg

BEGIN;
COMMENT ON CONSTRAINT sites_domain_id_fkey ON "meta_public".sites IS NULL;
COMMIT;  

