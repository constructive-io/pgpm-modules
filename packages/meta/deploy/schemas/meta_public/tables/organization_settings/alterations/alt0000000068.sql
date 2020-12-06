-- Deploy: schemas/meta_public/tables/organization_settings/alterations/alt0000000068 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/organization_settings/table

BEGIN;
ALTER TABLE "meta_public".organization_settings ADD CONSTRAINT organization_settings_legal_name_chk CHECK (character_length(legal_name) <= 255);
COMMIT;
