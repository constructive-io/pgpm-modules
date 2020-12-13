-- Deploy: schemas/rls_public/tables/organization_profiles/constraints/organization_profiles_organization_id_fkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/users/columns/id/column
-- requires: schemas/rls_public/tables/organization_profiles/table
-- requires: schemas/rls_public/tables/organization_profiles/columns/organization_id/column

BEGIN;

ALTER TABLE "rls_public".organization_profiles 
    ADD CONSTRAINT organization_profiles_organization_id_fkey 
    FOREIGN KEY (organization_id)
    REFERENCES "rls_public".users (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
COMMIT;
