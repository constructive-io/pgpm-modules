-- Deploy: schemas/rls_public/tables/user_connections/constraints/user_connections_requester_id_responder_id_key to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_connections/table

BEGIN;

ALTER TABLE "rls_public".user_connections
    ADD CONSTRAINT user_connections_requester_id_responder_id_key UNIQUE (requester_id,responder_id);
COMMIT;
