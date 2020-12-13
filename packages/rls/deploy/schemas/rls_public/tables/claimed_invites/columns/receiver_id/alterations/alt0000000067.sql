-- Deploy: schemas/rls_public/tables/claimed_invites/columns/receiver_id/alterations/alt0000000067 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/claimed_invites/table
-- requires: schemas/rls_public/tables/claimed_invites/columns/receiver_id/column

BEGIN;

ALTER TABLE "rls_public".claimed_invites 
    ALTER COLUMN receiver_id SET NOT NULL;
COMMIT;
