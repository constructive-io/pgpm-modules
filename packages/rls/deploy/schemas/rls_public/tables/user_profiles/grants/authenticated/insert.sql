-- Deploy: schemas/rls_public/tables/user_profiles/grants/authenticated/insert to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_profiles/table

BEGIN;
GRANT INSERT ON TABLE "rls_public".user_profiles TO authenticated;
COMMIT;
