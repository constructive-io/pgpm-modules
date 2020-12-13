-- Deploy: schemas/rls_public/alterations/alt0000000125 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT user_connections_requester_id_responder_id_key ON "rls_public".user_connections IS NULL;
COMMIT;
