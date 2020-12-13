-- Deploy: schemas/rls_public/tables/invites/columns/id/alterations/alt0000000047 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table
-- requires: schemas/rls_public/tables/invites/columns/id/column

BEGIN;

ALTER TABLE "rls_public".invites 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;
