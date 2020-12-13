-- Deploy: schemas/rls_public/tables/user_connections/indexes/user_connections_requester_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_connections/table

BEGIN;

CREATE INDEX user_connections_requester_id_idx ON "rls_public".user_connections (requester_id);
COMMIT;
