-- Deploy: schemas/rls_public/tables/invites/indexes/invites_sender_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/invites/table

BEGIN;

CREATE INDEX invites_sender_id_idx ON "rls_public".invites (sender_id);
COMMIT;
