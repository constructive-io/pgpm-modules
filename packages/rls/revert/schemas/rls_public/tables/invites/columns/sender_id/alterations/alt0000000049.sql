-- Revert: schemas/rls_public/tables/invites/columns/sender_id/alterations/alt0000000049 from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    ALTER COLUMN sender_id DROP DEFAULT;

COMMIT;  

