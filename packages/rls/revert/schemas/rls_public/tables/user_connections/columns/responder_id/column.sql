-- Revert: schemas/rls_public/tables/user_connections/columns/responder_id/column from pg

BEGIN;


ALTER TABLE "rls_public".user_connections DROP COLUMN responder_id;
COMMIT;  

