-- Deploy: schemas/rls_public/tables/users/grants/authenticated/delete to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table

BEGIN;
GRANT DELETE ON TABLE "rls_public".users TO authenticated;
COMMIT;
