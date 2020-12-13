-- Revert: schemas/rls_public/alterations/alt0000000131 from pg

BEGIN;
COMMENT ON CONSTRAINT organization_profiles_organization_id_key ON "rls_public".organization_profiles IS NULL;
COMMIT;  

