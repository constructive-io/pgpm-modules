-- Deploy: schemas/rls_public/tables/organization_settings/columns/id/alterations/alt0000000092 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_settings/table
-- requires: schemas/rls_public/tables/organization_settings/columns/id/column

BEGIN;

ALTER TABLE "rls_public".organization_settings 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;
