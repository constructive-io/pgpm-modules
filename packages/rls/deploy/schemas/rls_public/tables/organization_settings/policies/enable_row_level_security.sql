-- Deploy: schemas/rls_public/tables/organization_settings/policies/enable_row_level_security to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_settings/table

BEGIN;

ALTER TABLE "rls_public".organization_settings
    ENABLE ROW LEVEL SECURITY;
COMMIT;
