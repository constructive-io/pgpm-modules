-- Deploy: schemas/rls_public/tables/organization_profiles/indexes/organization_profiles_organization_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_profiles/table

BEGIN;

CREATE INDEX organization_profiles_organization_id_idx ON "rls_public".organization_profiles (organization_id);
COMMIT;
