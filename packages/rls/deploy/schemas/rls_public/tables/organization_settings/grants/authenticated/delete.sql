-- Deploy: schemas/rls_public/tables/organization_settings/grants/authenticated/delete to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_settings/table

BEGIN;
GRANT DELETE ON TABLE "rls_public".organization_settings TO authenticated;
COMMIT;
