-- Deploy: schemas/rls_public/tables/claimed_invites/columns/receiver_id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/claimed_invites/table

BEGIN;

ALTER TABLE "rls_public".claimed_invites ADD COLUMN receiver_id uuid;
COMMIT;
