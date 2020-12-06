-- Deploy: schemas/meta_public/tables/organization_settings/columns/id/alterations/alt0000000066 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/organization_settings/table
-- requires: schemas/meta_public/tables/organization_settings/columns/id/column

BEGIN;

ALTER TABLE "meta_public".organization_settings 
    ALTER COLUMN id SET NOT NULL;
COMMIT;
