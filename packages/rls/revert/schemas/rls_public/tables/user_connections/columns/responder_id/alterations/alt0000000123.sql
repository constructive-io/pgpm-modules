-- Revert: schemas/rls_public/tables/user_connections/columns/responder_id/alterations/alt0000000123 from pg

BEGIN;


ALTER TABLE "rls_public".user_connections 
    ALTER COLUMN responder_id DROP NOT NULL;


COMMIT;  

