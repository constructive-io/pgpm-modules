-- Deploy: schemas/rls_public/tables/invites/columns/multiple/alterations/alt0000000059 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table
-- requires: schemas/rls_public/tables/invites/columns/multiple/column

BEGIN;

ALTER TABLE "rls_public".invites 
    ALTER COLUMN multiple SET DEFAULT FALSE;
COMMIT;
