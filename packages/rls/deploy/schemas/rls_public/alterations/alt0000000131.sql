-- Deploy: schemas/rls_public/alterations/alt0000000131 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT organization_profiles_organization_id_key ON "rls_public".organization_profiles IS NULL;
COMMIT;
