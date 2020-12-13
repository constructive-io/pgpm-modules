-- Deploy: schemas/rls_public/tables/organization_settings/constraints/organization_settings_organization_id_key to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_settings/table

BEGIN;

ALTER TABLE "rls_public".organization_settings
    ADD CONSTRAINT organization_settings_organization_id_key UNIQUE (organization_id);
COMMIT;
