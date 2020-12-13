-- Deploy: schemas/rls_public/tables/user_settings/indexes/user_settings_user_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table

BEGIN;

CREATE INDEX user_settings_user_id_idx ON "rls_public".user_settings (user_id);
COMMIT;
