-- Deploy: schemas/rls_public/tables/users/alterations/alt0000000005 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table

BEGIN;

ALTER TABLE "rls_public".users
    DISABLE ROW LEVEL SECURITY;
COMMIT;
