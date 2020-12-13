-- Deploy: schemas/rls_public/tables/users/grants/authenticated/insert to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table

BEGIN;
GRANT INSERT ON TABLE "rls_public".users TO authenticated;
COMMIT;
