-- Revert: schemas/rls_public/tables/organization_settings/triggers/tg_timestamps from pg

BEGIN;


ALTER TABLE "rls_public".organization_settings DROP COLUMN created_at;
ALTER TABLE "rls_public".organization_settings DROP COLUMN updated_at;

DROP TRIGGER tg_timestamps ON "rls_public".organization_settings;

COMMIT;  

