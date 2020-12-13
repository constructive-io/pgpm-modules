-- Deploy: schemas/rls_public/tables/organization_settings/constraints/organization_settings_organization_id_fkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/users/columns/id/column
-- requires: schemas/rls_public/tables/organization_settings/table
-- requires: schemas/rls_public/tables/organization_settings/columns/organization_id/column

BEGIN;

ALTER TABLE "rls_public".organization_settings 
    ADD CONSTRAINT organization_settings_organization_id_fkey 
    FOREIGN KEY (organization_id)
    REFERENCES "rls_public".users (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
COMMIT;
