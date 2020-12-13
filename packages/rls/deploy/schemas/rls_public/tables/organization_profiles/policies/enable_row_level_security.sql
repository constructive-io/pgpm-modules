-- Deploy: schemas/rls_public/tables/organization_profiles/policies/enable_row_level_security to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_profiles/table

BEGIN;

ALTER TABLE "rls_public".organization_profiles
    ENABLE ROW LEVEL SECURITY;
COMMIT;
