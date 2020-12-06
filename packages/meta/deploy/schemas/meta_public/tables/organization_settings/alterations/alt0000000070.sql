-- Deploy: schemas/meta_public/tables/organization_settings/alterations/alt0000000070 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/organization_settings/table

BEGIN;
ALTER TABLE "meta_public".organization_settings ADD CONSTRAINT organization_settings_industry_chk CHECK (character_length(industry) <= 255);
COMMIT;
