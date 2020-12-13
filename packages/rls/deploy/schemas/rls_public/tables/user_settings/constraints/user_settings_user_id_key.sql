-- Deploy: schemas/rls_public/tables/user_settings/constraints/user_settings_user_id_key to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table

BEGIN;

ALTER TABLE "rls_public".user_settings
    ADD CONSTRAINT user_settings_user_id_key UNIQUE (user_id);
COMMIT;
