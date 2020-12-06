-- Revert: schemas/meta_public/tables/organization_settings/alterations/alt0000000069 from pg

BEGIN;
ALTER TABLE "meta_public".organization_settings DROP CONSTRAINT organization_settings_dba_chk;
COMMIT;  

