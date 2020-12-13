-- Revert: schemas/rls_public/alterations/alt0000000122 from pg

BEGIN;
COMMENT ON CONSTRAINT user_connections_requester_id_fkey ON "rls_public".user_connections IS NULL;
COMMIT;  

