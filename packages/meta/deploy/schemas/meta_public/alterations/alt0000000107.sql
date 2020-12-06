-- Deploy: schemas/meta_public/alterations/alt0000000107 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT sites_domain_id_key ON "meta_public".sites IS NULL;
COMMIT;
