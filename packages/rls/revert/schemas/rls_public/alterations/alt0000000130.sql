-- Revert: schemas/rls_public/alterations/alt0000000130 from pg

BEGIN;
COMMENT ON CONSTRAINT organization_profiles_organization_id_fkey ON "rls_public".organization_profiles IS NULL;
COMMIT;  

