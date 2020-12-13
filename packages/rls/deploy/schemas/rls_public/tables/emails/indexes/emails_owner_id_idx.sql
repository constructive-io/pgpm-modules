-- Deploy: schemas/rls_public/tables/emails/indexes/emails_owner_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table

BEGIN;

CREATE INDEX emails_owner_id_idx ON "rls_public".emails (owner_id);
COMMIT;
