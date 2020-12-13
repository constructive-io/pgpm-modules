-- Deploy: schemas/rls_public/tables/user_connections/alterations/alt0000000118 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_connections/table

BEGIN;

ALTER TABLE "rls_public".user_connections
    DISABLE ROW LEVEL SECURITY;
COMMIT;
