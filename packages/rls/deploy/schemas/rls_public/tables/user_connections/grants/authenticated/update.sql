-- Deploy: schemas/rls_public/tables/user_connections/grants/authenticated/update to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_connections/table

BEGIN;
GRANT UPDATE ( accepted ) ON TABLE "rls_public".user_connections TO authenticated;
COMMIT;
