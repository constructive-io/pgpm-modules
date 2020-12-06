-- Deploy: schemas/meta_public/alterations/alt0000000142 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT apps_site_id_key ON "meta_public".apps IS NULL;
COMMIT;
