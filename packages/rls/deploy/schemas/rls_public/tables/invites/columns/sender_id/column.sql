-- Deploy: schemas/rls_public/tables/invites/columns/sender_id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table

BEGIN;

ALTER TABLE "rls_public".invites ADD COLUMN sender_id uuid;
COMMIT;
