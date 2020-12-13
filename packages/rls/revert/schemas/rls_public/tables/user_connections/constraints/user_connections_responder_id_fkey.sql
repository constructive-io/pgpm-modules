-- Revert: schemas/rls_public/tables/user_connections/constraints/user_connections_responder_id_fkey from pg

BEGIN;


ALTER TABLE "rls_public".user_connections 
    DROP CONSTRAINT user_connections_responder_id_fkey;

COMMIT;  

