-- Deploy: schemas/rls_public/alterations/alt0000000076 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT user_profiles_user_id_key ON "rls_public".user_profiles IS NULL;
COMMIT;
