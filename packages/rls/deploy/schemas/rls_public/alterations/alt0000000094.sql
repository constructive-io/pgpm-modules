-- Deploy: schemas/rls_public/alterations/alt0000000094 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT organization_settings_organization_id_fkey ON "rls_public".organization_settings IS E'@omit manyToMany';
COMMIT;
