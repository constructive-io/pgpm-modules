-- Deploy: schemas/meta_public/tables/organization_settings/alterations/alt0000000065 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/organization_settings/table

BEGIN;

ALTER TABLE "meta_public".organization_settings
    DISABLE ROW LEVEL SECURITY;
COMMIT;
