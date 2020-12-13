-- Revert: schemas/rls_public/alterations/alt0000000125 from pg

BEGIN;
COMMENT ON CONSTRAINT user_connections_requester_id_responder_id_key ON "rls_public".user_connections IS NULL;
COMMIT;  

