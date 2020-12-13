-- Deploy: schemas/rls_public/alterations/alt0000000124 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT user_connections_responder_id_fkey ON "rls_public".user_connections IS NULL;
COMMIT;
