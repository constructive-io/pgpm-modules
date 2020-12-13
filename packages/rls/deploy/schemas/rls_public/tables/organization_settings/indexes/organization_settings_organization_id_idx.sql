-- Deploy: schemas/rls_public/tables/organization_settings/indexes/organization_settings_organization_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_settings/table

BEGIN;

CREATE INDEX organization_settings_organization_id_idx ON "rls_public".organization_settings (organization_id);
COMMIT;
