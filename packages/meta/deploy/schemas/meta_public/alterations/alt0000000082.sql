-- Deploy: schemas/meta_public/alterations/alt0000000082 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT domains_subdomain_domain_key ON "meta_public".domains IS NULL;
COMMIT;
