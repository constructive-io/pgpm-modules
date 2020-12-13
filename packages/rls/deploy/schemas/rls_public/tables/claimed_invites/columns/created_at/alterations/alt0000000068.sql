-- Deploy: schemas/rls_public/tables/claimed_invites/columns/created_at/alterations/alt0000000068 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/claimed_invites/table
-- requires: schemas/rls_public/tables/claimed_invites/columns/created_at/column

BEGIN;

ALTER TABLE "rls_public".claimed_invites 
    ALTER COLUMN created_at SET NOT NULL;
COMMIT;
