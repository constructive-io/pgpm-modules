-- Deploy: schemas/meta_public/tables/organization_settings/alterations/alt0000000069 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/organization_settings/table

BEGIN;
ALTER TABLE "meta_public".organization_settings ADD CONSTRAINT organization_settings_dba_chk CHECK (character_length(dba) <= 255);
COMMIT;
