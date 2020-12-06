-- Deploy: schemas/meta_public/alterations/alt0000000097 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT apis_domain_id_key ON "meta_public".apis IS NULL;
COMMIT;
