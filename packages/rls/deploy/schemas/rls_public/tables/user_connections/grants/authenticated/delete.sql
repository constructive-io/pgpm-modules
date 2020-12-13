-- Deploy: schemas/rls_public/tables/user_connections/grants/authenticated/delete to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_connections/table

BEGIN;
GRANT DELETE ON TABLE "rls_public".user_connections TO authenticated;
COMMIT;
