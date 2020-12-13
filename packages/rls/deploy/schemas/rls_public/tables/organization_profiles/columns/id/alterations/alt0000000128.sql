-- Deploy: schemas/rls_public/tables/organization_profiles/columns/id/alterations/alt0000000128 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_profiles/table
-- requires: schemas/rls_public/tables/organization_profiles/columns/id/column

BEGIN;

ALTER TABLE "rls_public".organization_profiles 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;
