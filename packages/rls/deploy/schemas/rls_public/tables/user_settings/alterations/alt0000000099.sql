-- Deploy: schemas/rls_public/tables/user_settings/alterations/alt0000000099 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table

BEGIN;
ALTER TABLE "rls_public".user_settings ADD CONSTRAINT user_settings_first_name_chk CHECK (character_length(first_name) <= 64);
COMMIT;
