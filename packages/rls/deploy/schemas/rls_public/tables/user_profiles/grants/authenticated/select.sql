-- Deploy: schemas/rls_public/tables/user_profiles/grants/authenticated/select to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_profiles/table

BEGIN;
GRANT SELECT ON TABLE "rls_public".user_profiles TO authenticated;
COMMIT;
