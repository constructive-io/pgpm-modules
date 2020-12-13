-- Deploy: schemas/rls_public/tables/organization_profiles/columns/description/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_profiles/table

BEGIN;

ALTER TABLE "rls_public".organization_profiles ADD COLUMN description text;
COMMIT;
