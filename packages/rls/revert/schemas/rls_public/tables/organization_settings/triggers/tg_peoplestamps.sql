-- Revert: schemas/rls_public/tables/organization_settings/triggers/tg_peoplestamps from pg

BEGIN;


ALTER TABLE "rls_public".organization_settings DROP COLUMN created_by;
ALTER TABLE "rls_public".organization_settings DROP COLUMN updated_by;

DROP TRIGGER tg_peoplestamps
ON "rls_public".organization_settings;


COMMIT;  

