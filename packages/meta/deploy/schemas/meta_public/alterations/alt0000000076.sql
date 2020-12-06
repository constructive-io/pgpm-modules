-- Deploy: schemas/meta_public/alterations/alt0000000076 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT organization_settings_organization_id_key ON "meta_public".organization_settings IS E'@omit';
COMMIT;
