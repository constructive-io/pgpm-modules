-- Deploy: schemas/rls_public/alterations/alt0000000095 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT organization_settings_organization_id_key ON "rls_public".organization_settings IS E'@omit';
COMMIT;
