-- Deploy: schemas/rls_public/tables/invites/indexes/invites_invite_valid_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table

BEGIN;

CREATE INDEX invites_invite_valid_idx ON "rls_public".invites (invite_valid);
COMMIT;
