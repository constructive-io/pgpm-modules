-- Deploy: schemas/meta_public/tables/organization_settings/columns/id/alterations/alt0000000067 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/organization_settings/table
-- requires: schemas/meta_public/tables/organization_settings/columns/id/column

BEGIN;

ALTER TABLE "meta_public".organization_settings 
    ALTER COLUMN id SET DEFAULT "meta_private".uuid_generate_v4();
COMMIT;
