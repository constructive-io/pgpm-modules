-- Deploy: schemas/rls_public/tables/organization_profiles/columns/organization_id/alterations/alt0000000129 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_profiles/table
-- requires: schemas/rls_public/tables/organization_profiles/columns/organization_id/column

BEGIN;

ALTER TABLE "rls_public".organization_profiles 
    ALTER COLUMN organization_id SET NOT NULL;
COMMIT;
