-- Deploy: schemas/rls_public/tables/claimed_invites/columns/sender_id/alterations/alt0000000066 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/claimed_invites/table
-- requires: schemas/rls_public/tables/claimed_invites/columns/sender_id/column

BEGIN;

ALTER TABLE "rls_public".claimed_invites 
    ALTER COLUMN sender_id SET NOT NULL;
COMMIT;
