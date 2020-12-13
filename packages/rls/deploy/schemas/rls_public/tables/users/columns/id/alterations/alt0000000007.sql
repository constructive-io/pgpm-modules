-- Deploy: schemas/rls_public/tables/users/columns/id/alterations/alt0000000007 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/users/columns/id/column

BEGIN;

ALTER TABLE "rls_public".users 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;
