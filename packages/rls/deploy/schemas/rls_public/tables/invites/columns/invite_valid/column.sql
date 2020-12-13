-- Deploy: schemas/rls_public/tables/invites/columns/invite_valid/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table

BEGIN;

ALTER TABLE "rls_public".invites ADD COLUMN invite_valid boolean;
COMMIT;
