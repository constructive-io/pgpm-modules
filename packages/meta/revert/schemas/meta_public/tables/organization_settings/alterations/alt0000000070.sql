-- Revert: schemas/meta_public/tables/organization_settings/alterations/alt0000000070 from pg

BEGIN;
ALTER TABLE "meta_public".organization_settings DROP CONSTRAINT organization_settings_industry_chk;
COMMIT;  

