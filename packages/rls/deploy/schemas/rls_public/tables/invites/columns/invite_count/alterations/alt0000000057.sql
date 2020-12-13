-- Deploy: schemas/rls_public/tables/invites/columns/invite_count/alterations/alt0000000057 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table
-- requires: schemas/rls_public/tables/invites/columns/invite_count/column

BEGIN;

ALTER TABLE "rls_public".invites 
    ALTER COLUMN invite_count SET DEFAULT 0;
COMMIT;
