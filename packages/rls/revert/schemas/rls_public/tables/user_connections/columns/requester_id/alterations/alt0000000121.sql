-- Revert: schemas/rls_public/tables/user_connections/columns/requester_id/alterations/alt0000000121 from pg

BEGIN;


ALTER TABLE "rls_public".user_connections 
    ALTER COLUMN requester_id DROP NOT NULL;


COMMIT;  

