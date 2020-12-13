-- Revert: schemas/rls_public/tables/user_connections/indexes/user_connections_responder_id_idx from pg

BEGIN;


DROP INDEX "rls_public".user_connections_responder_id_idx;

COMMIT;  

