-- Deploy: schemas/rls_public/tables/invites/columns/created_at/alterations/alt0000000063 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table
-- requires: schemas/rls_public/tables/invites/columns/created_at/column

BEGIN;

ALTER TABLE "rls_public".invites 
    ALTER COLUMN created_at SET DEFAULT NOW();
COMMIT;
