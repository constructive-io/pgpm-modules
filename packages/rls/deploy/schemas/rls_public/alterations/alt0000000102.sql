-- Deploy: schemas/rls_public/alterations/alt0000000102 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT user_settings_user_id_fkey ON "rls_public".user_settings IS NULL;
COMMIT;
