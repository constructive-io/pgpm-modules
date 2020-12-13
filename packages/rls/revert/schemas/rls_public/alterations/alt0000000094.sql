-- Revert: schemas/rls_public/alterations/alt0000000094 from pg

BEGIN;
COMMENT ON CONSTRAINT organization_settings_organization_id_fkey ON "rls_public".organization_settings IS NULL;
COMMIT;  

