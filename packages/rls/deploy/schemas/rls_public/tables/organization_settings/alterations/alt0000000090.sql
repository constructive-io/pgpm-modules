-- Deploy: schemas/rls_public/tables/organization_settings/alterations/alt0000000090 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_settings/table

BEGIN;

ALTER TABLE "rls_public".organization_settings
    DISABLE ROW LEVEL SECURITY;
COMMIT;
