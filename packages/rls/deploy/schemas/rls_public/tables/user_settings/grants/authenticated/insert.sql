-- Deploy: schemas/rls_public/tables/user_settings/grants/authenticated/insert to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_settings/table

BEGIN;
GRANT INSERT ON TABLE "rls_public".user_settings TO authenticated;
COMMIT;
