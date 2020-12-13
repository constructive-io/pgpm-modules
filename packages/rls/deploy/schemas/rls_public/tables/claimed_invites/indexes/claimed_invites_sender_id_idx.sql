-- Deploy: schemas/rls_public/tables/claimed_invites/indexes/claimed_invites_sender_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/claimed_invites/table

BEGIN;

CREATE INDEX claimed_invites_sender_id_idx ON "rls_public".claimed_invites (sender_id);
COMMIT;
