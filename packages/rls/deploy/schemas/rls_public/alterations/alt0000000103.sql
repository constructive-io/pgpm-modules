-- Deploy: schemas/rls_public/alterations/alt0000000103 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT user_settings_user_id_key ON "rls_public".user_settings IS NULL;
COMMIT;
