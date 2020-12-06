-- Revert: schemas/meta_public/alterations/alt0000000082 from pg

BEGIN;
COMMENT ON CONSTRAINT domains_subdomain_domain_key ON "meta_public".domains IS NULL;
COMMIT;  

