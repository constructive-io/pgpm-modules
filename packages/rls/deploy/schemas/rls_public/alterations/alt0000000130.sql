-- Deploy: schemas/rls_public/alterations/alt0000000130 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT organization_profiles_organization_id_fkey ON "rls_public".organization_profiles IS NULL;
COMMIT;
