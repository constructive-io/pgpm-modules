-- Deploy: schemas/rls_public/tables/organization_settings/columns/organization_id/alterations/alt0000000093 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_settings/table
-- requires: schemas/rls_public/tables/organization_settings/columns/organization_id/column

BEGIN;

ALTER TABLE "rls_public".organization_settings 
    ALTER COLUMN organization_id SET NOT NULL;
COMMIT;
